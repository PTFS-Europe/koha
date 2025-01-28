#!/usr/bin/perl

#  This script loops through each overdue item, determines the fine,
#  and updates the total amount of fines due by each user.  It relies on
#  the existence of /tmp/fines, which is created by ???
# Doesn't really rely on it, it relies on being able to write to /tmp/
# It creates the fines file
#
#  This script is meant to be run nightly out of cron.

# Copyright 2011-2012 BibLibre
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Date::Calc qw( Date_to_Days );

use Koha::Script -cron;
use C4::Context;
use C4::Overdues qw( CalcFine checkoverdues GetFine Getoverdues );
use C4::Calendar qw();    # don't need any exports from Calendar
use C4::Log qw( cronlogaction );
use Getopt::Long qw( GetOptions );
use List::MoreUtils qw( none );
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Patrons;

my $help    = 0;
my $verbose = 0;
my @pcategories;
my @categories;
my %catamounts;
my @libraries;
my $delay;
my $useborrowerlibrary;
my $borrowernumberlimit;
my $borrowersalreadyapplied; # hashref of borrowers for whom we already applied the fine, so it's only applied once
my $debug = 0;
my $bigdebug = 0;

my $command_line_options = join(" ",@ARGV);
cronlogaction({ info => $command_line_options });

GetOptions(
    'h|help'      => \$help,
    'v|verbose'   => \$verbose,
    'c|category:s'=> \@pcategories,
    'l|library:s' => \@libraries,
    'd|delay:i'   => \$delay,
    'u|use-borrower-library' => \$useborrowerlibrary,
    'b|borrower:i' => \$borrowernumberlimit
);
my $usage = << 'ENDUSAGE';

This script calculates and charges overdue fines to patron accounts.

If the Koha System Preference 'finesMode' is set to 'production', the fines are charged to the patron accounts.

Please note that the fines won't be applied on a holiday.

This script has the following parameters :
    -h --help: this message
    -v --verbose
    -c --category borrower_category,amount (repeatable)
    -l --library (repeatable)
    -d --delay
    -u --use-borrower-library: use borrower's library, regardless of the CircControl syspref
    -b --borrower borrowernumber: only for one given borrower

ENDUSAGE
die $usage if $help;

my $dbh = C4::Context->dbh;

# Processing categories
foreach (@pcategories) {
    my ($category, $amount) = split(',', $_);
    push @categories, $category;
    $catamounts{$category} = $amount;
}

use vars qw(@borrower_fields @item_fields @other_fields);
use vars qw($fldir $libname $control $branch_type $mode $delim $dbname $today $today_iso $today_days);
use vars qw($filename);

CHECK {
    @borrower_fields = qw(cardnumber categorycode surname firstname email phone address citystate);
    @item_fields     = qw(itemnumber barcode date_due);
    @other_fields    = qw(type days_overdue fine);
    $libname         = C4::Context->preference('LibraryName');
    $control         = C4::Context->preference('CircControl');
    $branch_type     = C4::Context->preference('HomeOrHoldingBranch') || 'homebranch';
    $mode            = C4::Context->preference('finesMode');
    $dbname          = C4::Context->config('database');
    $delim           = "\t";                                                                          # ?  C4::Context->preference('delimiter') || "\t";

}

INIT {
    $debug and print "Each line will contain the following fields:\n",
      "From borrowers : ", join( ', ', @borrower_fields ), "\n",
      "From items : ",     join( ', ', @item_fields ),     "\n",
      "Per overdue: ",     join( ', ', @other_fields ),    "\n",
      "Delimiter: '$delim'\n";
}
$debug and (defined $borrowernumberlimit) and print "--borrower limitation: borrower $borrowernumberlimit\n";
my ($numOverdueItems, $data);
if (defined $borrowernumberlimit) {
    ($numOverdueItems, $data) = checkoverdues($borrowernumberlimit);
} else {
    $data = Getoverdues();
    $numOverdueItems = scalar @$data;
}
my $overdueItemsCounted = 0;
my %calendars           = ();
$today      = dt_from_string;
$today_iso  = $today->ymd;
my ($tyear, $tmonth, $tday) = split( /-/, $today_iso );
$today_days = Date_to_Days( $tyear, $tmonth, $tday );

for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
    next if $data->[$i]->{'itemlost'};
    my ( $datedue, $datedue_days );
    eval {
        $datedue = dt_from_string( $data->[$i]->{'date_due'} );
        my $datedue_iso = output_pref( { dt => $datedue, dateonly => 1, dateformat => 'iso' } );
        $datedue_days = Date_to_Days( split( /-/, $datedue_iso ) );
    };
    if ($@) {
    warn "Error on date for borrower " . $data->[$i]->{'borrowernumber'} .  ": $@date_due: " . $data->[$i]->{'date_due'} . "\ndatedue_days: " . $datedue_days . "\nSkipping";
    next;
    }
    my $due_str = output_pref( { dt => $datedue, dateonly => 1 } );
    unless ( defined $data->[$i]->{'borrowernumber'} ) {
        print STDERR "ERROR in Getoverdues line $i: issues.borrowernumber IS NULL.  Repair 'issues' table now!  Skipping record.\n";
        next;    # Note: this doesn't solve everything.  After NULL borrowernumber, multiple issues w/ real borrowernumbers can pile up.
    }
    my $patron = Koha::Patrons->find( $data->[$i]->{'borrowernumber'} );

    # Skipping borrowers that are not in @categories
    $bigdebug and warn "Skipping borrower from category " . $patron->categorycode if none { $patron->categorycode eq $_ } @categories;
    next if none { $patron->categorycode eq $_ } @categories;

    my $branchcode =
        ( $useborrowerlibrary )           ? $patron->branchcode
      : ( $control eq 'ItemHomeLibrary' ) ? $data->[$i]->{$branch_type}
      : ( $control eq 'PatronLibrary' )   ? $patron->branchcode
      :                                     $data->[$i]->{branchcode};
    # In final case, CircControl must be PickupLibrary. (branchcode comes from issues table here).

    # Skipping branchcodes that are not in @libraries
    $bigdebug and warn "Skipping library $branchcode" if none { $branchcode eq $_ } @libraries;
    next if none { $branchcode eq $_ } @libraries;

    my $calendar;
    unless ( defined( $calendars{$branchcode} ) ) {
        $calendars{$branchcode} = C4::Calendar->new( branchcode => $branchcode );
    }
    $calendar = $calendars{$branchcode};
    my $isHoliday = $calendar->isHoliday( $tday, $tmonth, $tyear );

    # Reassing datedue_days if -delay specified in commandline
    $bigdebug and warn "Using commandline supplied delay : $delay" if ($delay);
    $datedue_days += $delay if ($delay);

    ( $datedue_days <= $today_days ) or next;    # or it's not overdue, right?

    $overdueItemsCounted++;
    my ( $amount, $unitcounttotal, $unitcount ) = CalcFine(
        $data->[$i],
        $patron->categorycode,
        $branchcode,
        $datedue,
        $today,
    );

    # Reassign fine's amount if specified in command-line
    $amount = $catamounts{$patron->categorycode} if (defined $catamounts{$patron->categorycode});

    # We check if there is already a fine for the given borrower
    my $fine = GetFine(undef, $data->[$i]->{'borrowernumber'});
    if ($fine > 0) {
        $debug and warn "There is already a fine for borrower " . $data->[$i]->{'borrowernumber'} . ". Nothing to do here. Skipping this borrower";
        next;
    }

    # Don't update the fine if today is a holiday.
    # This ensures that dropbox mode will remove the correct amount of fine.
    if ( $mode eq 'production' and !$borrowersalreadyapplied->{$data->[$i]->{'borrowernumber'}}) {
        # If we're on a holiday, warn the user (if debug) that no fine will be applied
        if($isHoliday) {
            $debug and warn "Today is a holiday. The fine for borrower " . $data->[$i]->{'borrowernumber'} . " will not be applied";
        } else {
            $debug and warn "Creating fine for borrower " . $data->[$i]->{'borrowernumber'} . " with amount : $amount";

            # We mark this borrower as already processed
            $borrowersalreadyapplied->{$data->[$i]->{'borrowernumber'}} = 1;

            my $borrowernumber = $data->[$i]->{'borrowernumber'};
            my $itemnumber     = $data->[$i]->{'itemnumber'};

            # And we create the fine
            my $sth4 = $dbh->prepare( "SELECT title FROM biblio LEFT JOIN items ON biblio.biblionumber=items.biblionumber WHERE items.itemnumber=?" );
            $sth4->execute($itemnumber);
            my $title = $sth4->fetchrow;

            my $desc        = "staticfine";
            my $query       = "INSERT INTO accountlines
                        (borrowernumber,itemnumber,date,amount,description,debit_type_code,status,amountoutstanding)
                                VALUES (?,?,now(),?,?,'OVERDUE','RETURNED',?)";
            my $sth2 = $dbh->prepare($query);
            $bigdebug and warn "query: $query\nw/ args: $borrowernumber, $itemnumber, $amount, $desc, $amount\n";
            $sth2->execute( $borrowernumber, $itemnumber, $amount, $desc, $amount );

        }
    }
}

if ($verbose) {
    print <<EOM;
Fines assessment -- $today_iso
Number of Overdue Items:
     counted $overdueItemsCounted
    reported $numOverdueItems

EOM
}

cronlogaction({ action => 'End', info => "COMPLETED" });
