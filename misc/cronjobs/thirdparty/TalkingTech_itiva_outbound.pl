#!/usr/bin/perl
#
# Copyright (C) 2011 ByWater Solutions
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

use strict;
use warnings;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Getopt::Long;
use Pod::Usage;

use C4::Context;
use C4::Items;
use C4::Letters;
use C4::Overdues;
use Koha::Calendar;
use Koha::DateUtils;
use Koha::Patrons;
use Koha::Libraries;

sub usage {
    pod2usage( -verbose => 2 );
    exit;
}

die "TalkingTechItivaPhoneNotification system preference not activated... dying\n"
  unless ( C4::Context->preference("TalkingTechItivaPhoneNotification") );

# Database handle
my $dbh = C4::Context->dbh;

# Options
my $verbose;
my $language = "EN";
my @types;
my @holds_waiting_days_to_call;
my $library_code;
my $help;
my $outfile;
my $skip_patrons_with_email;
my $patron_branchcode;

# maps to convert I-tiva terms to Koha terms
my $type_module_map = {
    'PREOVERDUE' => 'circulation',
    'OVERDUE'    => 'circulation',
    'RESERVE'    => 'reserves',
};

my $type_notice_map = {
    'PREOVERDUE' => 'PREDUE',
    'OVERDUE'    => 'OVERDUE',
    'RESERVE'    => 'HOLD',
};

GetOptions(
    'o|output:s'             => \$outfile,
    'v'                      => \$verbose,
    'lang:s'                 => \$language,
    'type:s'                 => \@types,
    'w|waiting-hold-day:s'   => \@holds_waiting_days_to_call,
    'c|code|library-code:s'  => \$library_code,
    's|skip-patrons-with-email' => \$skip_patrons_with_email,
    'pb|patron-branchcode:s' => \$patron_branchcode,
    'h|help'                 => \$help,
);

$language = uc($language);
$library_code ||= '';

pod2usage( -verbose => 1 ) if $help;

if ($patron_branchcode) {
    die("Invalid branchcode '$patron_branchcode' passed in -pb --patron-branchcode parameter")
      unless Koha::Libraries->search( { branchcode => $patron_branchcode } )->count;
}

# output log or STDOUT
my $OUT;
if ( defined $outfile ) {
    open( $OUT, '>', "$outfile" ) || die("Cannot open output file");
} else {
    print "No output file defined; printing to STDOUT\n"
      if ( defined $verbose );
    $OUT = *STDOUT || die "Couldn't duplicate STDOUT: $!";
}

my $format = 'V';    # format for phone notifications

foreach my $type (@types) {
    $type = uc($type);    #just in case lower or mixed-case was supplied
    my $module = $type_module_map->{$type};    #since the module is required to get the letter
    my $code   = $type_notice_map->{$type};    #to get the Koha name of the notice

    my @loop;
    if ( $type eq 'OVERDUE' ) {
        @loop = GetOverdueIssues( $patron_branchcode );
    } elsif ( $type eq 'PREOVERDUE' ) {
        @loop = GetPredueIssues( $patron_branchcode );
    } elsif ( $type eq 'RESERVE' ) {
        @loop = GetWaitingHolds( $patron_branchcode );
    } else {
        print "Unknown or unsupported message type $type; skipping...\n"
          if ( defined $verbose );
        next;
    }

    my $patrons;
    foreach my $issues (@loop) {
        $patrons->{$issues->{borrowernumber}} ||= Koha::Patrons->find( $issues->{borrowernumber} ) if $skip_patrons_with_email;
        next if $skip_patrons_with_email && $patrons->{$issues->{borrowernumber}}->notice_email_address;

        my $date_dt = dt_from_string ( $issues->{'date_due'} );
        my $due_date = output_pref( { dt => $date_dt, dateonly => 1, dateformat =>'metric' } );

        my $letter = C4::Letters::GetPreparedLetter(
            module      => $module,
            letter_code => $code,
            lang        => 'default', # It does not sound useful to send a lang here
            tables      => {
                borrowers   => $issues->{'borrowernumber'},
                biblio      => $issues->{'biblionumber'},
                biblioitems => $issues->{'biblionumber'},
            },
            message_transport_type => 'phone',
        );

        die "No letter found for type $type!... dying\n" unless $letter;

        my $message_id = 0;
        if ($outfile) {
            $message_id = C4::Letters::EnqueueLetter(
                {   letter                 => $letter,
                    borrowernumber         => $issues->{'borrowernumber'},
                    message_transport_type => 'phone',
                }
            );
        }

        print $OUT "\"$format\",\"$language\",\"$type\",\"$issues->{level}\",\"$issues->{cardnumber}\",\"$issues->{patron_title}\",\"$issues->{firstname}\",";
        print $OUT "\"$issues->{surname}\",\"$issues->{phone}\",\"$issues->{email}\",\"$library_code\",";
        print $OUT "\"$issues->{site}\",\"$issues->{site_name}\",\"$issues->{barcode}\",\"$due_date\",\"$issues->{title}\",\"$message_id\"\n";
    }
}

=head1 NAME

TalkingTech_itiva_outbound.pl

=head1 SYNOPSIS

  TalkingTech_itiva_outbound.pl
  TalkingTech_itiva_outbound.pl --type=OVERDUE -w 0 -w 2 -w 6 --output=/tmp/talkingtech/outbound.csv
  TalkingTech_itiva_outbound.pl --type=RESERVE --type=PREOVERDUE --lang=FR


Script to generate Spec C outbound notifications file for Talking Tech i-tiva
phone notification system.

=over

=item B<--help> B<-h>

Prints this help

=item B<-v>

Provide verbose log information.

=item B<--output> B<-o>

Destination for outbound notifications file (CSV format).  If no value is specified,
output is dumped to screen.

=item B<--lang>

Sets the language for all outbound messages.  Currently supported values are EN, FR and ES.
If no value is specified, EN will be used by default.

=item B<--type>

REQUIRED. Sets which messaging types are to be used.  Can be given multiple times, to
specify multiple types in a single output file.  Currently supported values are RESERVE, PREOVERDUE
and OVERDUE.  If no value is given, this script will not produce any outbound notifications.

=item B<--waiting-hold-day> B<-w>

OPTIONAL for --type=RESERVE. Sets the days after a hold has been set to waiting on which to call. Use
switch as many times as desired. For example, passing "-w 0 -w 2 -w 6" will cause calls to be placed
on the day the hold was set to waiting, 2 days after the waiting date, and 6 days after. See example above.
If this switch is not used with --type=RESERVE, calls will be placed every day until the waiting reserve
is picked up or canceled.

=item B<--library-code> B<--code> B<-c>

OPTIONAL
The code of the source library of the message.
The library code is used to group notices together for
consortium purposes and apply library specific settings, such as
prompts, to those notices.
This field can be blank if all messages are from a single library.

=item B<--patron-branchcode> B<--pb>

OPTIONAL

Limits the the patrons to generate notices for based on the patron's home library.
Items and holds from other libraries will still be included for the given patron.

=back

=cut

sub GetOverdueIssues {
    my ( $patron_branchcode ) = @_;

    my $patron_branchcode_filter = $patron_branchcode ? "AND borrowers.branchcode = '$patron_branchcode'" : q{};

    my $query = "SELECT borrowers.borrowernumber, borrowers.cardnumber, borrowers.title as patron_title, borrowers.firstname, borrowers.surname,
                borrowers.phone, borrowers.email, borrowers.branchcode, biblio.biblionumber, biblio.title, items.barcode, issues.date_due,
                max(overduerules.branchcode) as rulebranch, TO_DAYS(NOW())-TO_DAYS(date_due) as daysoverdue, delay1, delay2, delay3,
                issues.branchcode as site, branches.branchname as site_name
                FROM borrowers JOIN issues USING (borrowernumber)
                JOIN items USING (itemnumber)
                JOIN biblio USING (biblionumber)
                JOIN branches ON (issues.branchcode = branches.branchcode)
                JOIN overduerules USING (categorycode)
                JOIN overduerules_transport_types USING ( overduerules_id )
                WHERE ( overduerules.branchcode = borrowers.branchcode or overduerules.branchcode = '')
                AND overduerules_transport_types.message_transport_type = 'phone'
                AND ( (TO_DAYS(NOW())-TO_DAYS(date_due) ) = delay1
                  OR  (TO_DAYS(NOW())-TO_DAYS(date_due) ) = delay2
                  OR  (TO_DAYS(NOW())-TO_DAYS(date_due) ) = delay3 )
                $patron_branchcode_filter
                GROUP BY items.itemnumber
                ";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @results;
    while ( my $issue = $sth->fetchrow_hashref() ) {
        if ( $issue->{'daysoverdue'} == $issue->{'delay1'} ) {
            $issue->{'level'} = 1;
        } elsif ( $issue->{'daysoverdue'} == $issue->{'delay2'} ) {
            $issue->{'level'} = 2;
        } elsif ( $issue->{'daysoverdue'} == $issue->{'delay3'} ) {
            $issue->{'level'} = 3;
        } else {

            # this shouldn't ever happen, based our SQL criteria
        }
        push @results, $issue;
    }
    return @results;
}

sub GetPredueIssues {
    my ( $patron_branchcode ) = @_;

    my $patron_branchcode_filter = $patron_branchcode ? "AND borrowers.branchcode = '$patron_branchcode'" : q{};

    my $query = "SELECT borrowers.borrowernumber, borrowers.cardnumber, borrowers.title as patron_title, borrowers.firstname, borrowers.surname,
                borrowers.phone, borrowers.email, borrowers.branchcode, biblio.biblionumber, biblio.title, items.barcode, issues.date_due,
                issues.branchcode as site, branches.branchname as site_name
                FROM borrowers JOIN issues USING (borrowernumber)
                JOIN items USING (itemnumber)
                JOIN biblio USING (biblionumber)
                JOIN branches ON (issues.branchcode = branches.branchcode)
                JOIN borrower_message_preferences USING (borrowernumber)
                JOIN borrower_message_transport_preferences USING (borrower_message_preference_id)
                JOIN message_attributes USING (message_attribute_id)
                WHERE ( TO_DAYS( date_due ) - TO_DAYS( NOW() ) ) = days_in_advance
                AND message_transport_type = 'phone'
                AND message_name = 'Advance_Notice'
                $patron_branchcode_filter
                ";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @results;
    while ( my $issue = $sth->fetchrow_hashref() ) {
        $issue->{'level'} = 1;    # only one level for Predue notifications
        push @results, $issue;
    }
    return @results;
}

sub GetWaitingHolds {
    my ( $patron_branchcode ) = @_;

    my $patron_branchcode_filter = $patron_branchcode ? "AND borrowers.branchcode = '$patron_branchcode'" : q{};

    my $query = "SELECT borrowers.borrowernumber, borrowers.cardnumber, borrowers.title as patron_title, borrowers.firstname, borrowers.surname,
                borrowers.phone, borrowers.email, borrowers.branchcode, biblio.biblionumber, biblio.title, items.barcode, reserves.waitingdate,
                reserves.branchcode AS site, branches.branchname AS site_name,
                TO_DAYS(NOW())-TO_DAYS(reserves.waitingdate) AS days_since_waiting
                FROM borrowers JOIN reserves USING (borrowernumber)
                JOIN items USING (itemnumber)
                JOIN biblio ON (biblio.biblionumber = items.biblionumber)
                JOIN branches ON (reserves.branchcode = branches.branchcode)
                JOIN borrower_message_preferences USING (borrowernumber)
                JOIN borrower_message_transport_preferences USING (borrower_message_preference_id)
                JOIN message_attributes USING (message_attribute_id)
                WHERE ( reserves.found = 'W' )
                AND message_transport_type = 'phone'
                AND message_name = 'Hold_Filled'
                $patron_branchcode_filter
                ";
    my $pickupdelay = C4::Context->preference("ReservesMaxPickUpDelay");
    my $sth         = $dbh->prepare($query);
    $sth->execute();
    my @results;
    while ( my $issue = $sth->fetchrow_hashref() ) {
        my $calendar = Koha::Calendar->new( branchcode => $issue->{'site'} );

        my $waiting_date = dt_from_string( $issue->{waitingdate}, 'sql' );
        my $pickup_date = $waiting_date->clone->add( days => $pickupdelay );
        if ( $calendar->is_holiday($pickup_date) ) {
            $pickup_date = $calendar->next_open_day( $pickup_date );
        }

        $issue->{'date_due'} = output_pref({dt => $pickup_date, dateformat => 'iso' });
        $issue->{'level'} = 1;    # only one level for Hold Waiting notifications

        my $days_to_subtract = 0;
        if ( $calendar->is_holiday($waiting_date) ) {
            my $next_open_day = $calendar->next_open_day( $waiting_date );
            $days_to_subtract = $calendar->days_between($waiting_date, $next_open_day)->days;
        }

        $issue->{'days_since_waiting'} = $issue->{'days_since_waiting'} - $days_to_subtract;

        if ( ( grep $_ eq $issue->{'days_since_waiting'}, @holds_waiting_days_to_call )
            || !scalar(@holds_waiting_days_to_call) ) {
            push @results, $issue;
        }
    }
    return @results;

}
