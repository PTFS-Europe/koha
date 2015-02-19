#!/usr/bin/perl

# Copyright 2007 Liblime
# Parts copyright 2010 BibLibre
# Parts copyright 2014 ByWater Solutions
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

use C4::Dates qw(format_date_in_iso);
use C4::Context;
use C4::Branch qw(GetBranchName);
use C4::Members;
use C4::Members::Attributes qw(:all);
use C4::Members::AttributeTypes;
use C4::Members::Messaging;
use Koha::Borrower::Debarments;

use Getopt::Long;
use Text::CSV;

my $extended = C4::Context->preference('ExtendedPatronAttributes');
my $set_messaging_prefs =
  C4::Context->preference('EnhancedMessagingPreferences');
my @columnkeys = C4::Members::columns();
if ($extended) {
    push @columnkeys, 'patron_attributes';
}
my $columnkeystpl =
  [ map { { 'key' => $_ } } grep { $_ ne 'borrowernumber' } @columnkeys ]
  ;    # ref. to array of hashrefs.

our $csv =
  Text::CSV->new( { binary => 1 } );    # binary needed for non-ASCII Unicode

my ( $template, $loggedinuser, $cookie );

my $csv_file;
my $matchpoint;
my $overwrite_cardnumber;
my %defaults;
my $ext_preserve = 0;
my $verbose;
my $help;

GetOptions(
    'c|csv=s'                       => \$csv_file,
    'm|matchpoint=s'                => \$matchpoint,
    'd|default=s'                   => \%defaults,
    'o|overwrite'                   => \$overwrite_cardnumber,
    'p|preserve-extended-atributes' => \$ext_preserve,
    'v|verbose'                     => \$verbose,
    'h|help|?'                      => \$help,
);

print_help() if ( $help || !$csv_file || !$matchpoint );

my $handle;
open( $handle, "<", $csv_file ) or die $!;

my $imported    = 0;
my $alreadyindb = 0;
my $overwritten = 0;
my $invalid     = 0;
my $matchpoint_attr_type;

# use header line to construct key to column map
my $borrowerline = <$handle>;
my $status       = $csv->parse($borrowerline);
print "WARNING: CSV header line is incomplete: $borrowerline\n" unless $status;
my @csvcolumns = $csv->fields();
my %csvkeycol;
my $col = 0;

foreach my $keycol (@csvcolumns) {

    # columnkeys don't contain whitespace, but some stupid tools add it
    $keycol =~ s/ +//g;
    $csvkeycol{$keycol} = $col++;
}
if ($extended) {
    $matchpoint_attr_type = C4::Members::AttributeTypes->fetch($matchpoint);
}

my $today_iso = C4::Dates->new()->output('iso');
my @criticals =
  qw(surname branchcode categorycode);    # there probably should be others
my @bad_dates;                            # I've had a few.
my $date_re = C4::Dates->new->regexp('syspref');
my $iso_re  = C4::Dates->new->regexp('iso');
LINE: while ( my $borrowerline = <$handle> ) {
    my %borrower;
    my @missing_criticals;
    my $patron_attributes;
    my $status  = $csv->parse($borrowerline);
    my @columns = $csv->fields();
    if ( !$status ) {
        push @missing_criticals,
          { badparse => 1, line => $., lineraw => $borrowerline };
        print "ERROR: Unable to parse line $.: $borrowerline";
    }
    elsif ( @columns == @columnkeys ) {
        @borrower{@columnkeys} = @columns;

        # MJR: try to fill blanks gracefully by using default values
        foreach my $key (@columnkeys) {
            if ( $borrower{$key} !~ /\S/ ) {
                $borrower{$key} = $defaults{$key};
            }
        }
    }
    else {
        # MJR: try to recover gracefully by using default values
        foreach my $key (@columnkeys) {
            if ( defined( $csvkeycol{$key} )
                and $columns[ $csvkeycol{$key} ] =~ /\S/ )
            {
                $borrower{$key} = $columns[ $csvkeycol{$key} ];
            }
            elsif ( $defaults{$key} ) {
                $borrower{$key} = $defaults{$key};
            }
            elsif ( scalar grep { $key eq $_ } @criticals ) {

                # a critical field is undefined
                print
"ERROR: missing critical column data '$key' for line $.: $borrowerline\n";
            }
            else {
                $borrower{$key} = '';
            }
        }
    }

    #warn join(':',%borrower);
    if ( $borrower{categorycode} ) {
        print "ERROR: invalid categorycode for line $.: $borrowerline\n"
          unless ( GetBorrowercategory( $borrower{categorycode} ) );
    }
    else {
        print "ERROR: missing categorycode for line $.: $borrowerline\n";
    }

    if ( $borrower{branchcode} ) {
        print "ERROR: invalid branchcode for line $.: $borrowerline\n"
          unless ( GetBranchName( $borrower{branchcode} ) );
    }
    else {
        print "ERROR: missing branchcode for line $.: $borrowerline\n";
    }

    if ($extended) {
        my $attr_str = $borrower{patron_attributes};

        # fixup double quotes in case we are passed smart quotes
        $attr_str =~ s/\xe2\x80\x9c/"/g;
        $attr_str =~ s/\xe2\x80\x9d/"/g;

        # not really a field in borrowers, so we don't want to pass it to ModMember.
        delete $borrower{patron_attributes};
        $patron_attributes = extended_attributes_code_value_arrayref($attr_str);
    }

    # Popular spreadsheet applications make it difficult to force date outputs to be zero-padded, but we require it.
    foreach (qw(dateofbirth dateenrolled dateexpiry)) {
        my $tempdate = $borrower{$_} or next;

        if ( $tempdate =~ /$date_re/ ) {
            $borrower{$_} = format_date_in_iso($tempdate);
        }
        elsif ( $tempdate =~ /$iso_re/ ) {
            $borrower{$_} = $tempdate;
        }
        else {
            $borrower{$_} = '';
            push @missing_criticals,
              {
                key      => $_,
                line     => $.,
                lineraw  => $borrowerline,
                bad_date => 1
              };
        }
    }

    $borrower{dateenrolled} = $today_iso unless $borrower{dateenrolled};

    $borrower{dateexpiry} =
      GetExpiryDate( $borrower{categorycode}, $borrower{dateenrolled} )
      unless $borrower{dateexpiry};

    my $borrowernumber;
    my $member;
    if ( ( $matchpoint eq 'cardnumber' ) && ( $borrower{'cardnumber'} ) ) {
        $member = GetMember( 'cardnumber' => $borrower{'cardnumber'} );
        if ($member) {
            $borrowernumber = $member->{'borrowernumber'};
        }
    }
    elsif ( ( $matchpoint eq 'userid' ) && ( $borrower{'userid'} ) ) {
        $member = GetMember( 'userid' => $borrower{'userid'} );
        if ($member) {
            $borrowernumber = $member->{'borrowernumber'};
        }
    }
    elsif ($extended) {
        if ( defined($matchpoint_attr_type) ) {
            foreach my $attr (@$patron_attributes) {
                if ( $attr->{code} eq $matchpoint and $attr->{value} ne '' ) {
                    my @borrowernumbers =
                      $matchpoint_attr_type->get_patrons( $attr->{value} );
                    $borrowernumber = $borrowernumbers[0]
                      if scalar(@borrowernumbers) == 1;
                    last;
                }
            }
        }
    }

    if ( C4::Members::checkcardnumber( $borrower{cardnumber}, $borrowernumber ) ) {
        $borrowernumber ||= q{};
        print "ERROR: invalid cardnumber '$borrower{cardnumber}' for borrowernumber $borrowernumber\n";
        $invalid++;
        next;
    }

    if ($borrowernumber) {

        # borrower exists
        unless ($overwrite_cardnumber) {
            $alreadyindb++;
            print "$borrower{'surname'} / $borrowernumber alredy in database.\n" if $verbose;
            next LINE;
        }

        $borrower{'borrowernumber'} = $borrowernumber;

        # use values from extant patron unless our csv file includes this column or we provided a default.
        for my $col ( keys %borrower ) {
            # The password is always encrypted, skip it!
            next if $col eq 'password';

            unless ( exists( $csvkeycol{$col} ) || $defaults{$col} ) {
                $borrower{$col} = $member->{$col} if ( $member->{$col} );
            }
        }

        unless ( ModMember(%borrower) ) {
            $invalid++;

            # untill we have better error trapping, we have no way of knowing why ModMember errored out...
            print "Failure to update $borrower{'surname'} / $borrowernumber\n"
              if $verbose;
            next LINE;
        }

        if ( $borrower{debarred} ) {

            # Check to see if this debarment already exists
            my $debarrments = GetDebarments(
                {
                    borrowernumber => $borrowernumber,
                    expiration     => $borrower{debarred},
                    comment        => $borrower{debarredcomment}
                }
            );

            # If it doesn't, then add it!
            unless (@$debarrments) {
                AddDebarment(
                    {
                        borrowernumber => $borrowernumber,
                        expiration     => $borrower{debarred},
                        comment        => $borrower{debarredcomment}
                    }
                );
            }
        }

        if ($extended) {
            if ($ext_preserve) {
                my $old_attributes = GetBorrowerAttributes($borrowernumber);
                $patron_attributes = extended_attributes_merge( $old_attributes, $patron_attributes );
            }
            SetBorrowerAttributes( $borrowernumber, $patron_attributes );
        }

        print "Overwriting $borrower{'surname'} / $borrowernumber with new data\n";
        $overwritten++;
    }
    else {
        if ( !$borrower{'cardnumber'} ) {
            $borrower{'cardnumber'} = fixup_cardnumber(undef);
        }

        if ( $borrowernumber = AddMember(%borrower) ) {

            if ( $borrower{debarred} ) {
                AddDebarment(
                    {
                        borrowernumber => $borrowernumber,
                        expiration     => $borrower{debarred},
                        comment        => $borrower{debarredcomment}
                    }
                );
            }

            if ($extended) {
                SetBorrowerAttributes( $borrowernumber, $patron_attributes );
            }

            if ($set_messaging_prefs) {
                C4::Members::Messaging::SetMessagingPreferencesFromDefaults(
                    {
                        borrowernumber => $borrowernumber,
                        categorycode   => $borrower{categorycode}
                    }
                );
            }

            $imported++;

            print "Imported new patron $borrower{'surname'} / $borrowernumber\n"
              if $verbose;
        }
        else {
            $invalid++;
            print "Failure to import $borrower{'surname'}\n" if $verbose;
        }
    }
}

if ($verbose) {
    my $total = $imported + $alreadyindb + $invalid + $overwritten;
    print "\nImport complete:\n";
    print "Imported:    $imported\n";
    print "Overwritten: $overwritten\n";
    print "Skipped:     $alreadyindb\n";
    print "Invalid:     $invalid\n";
    print "Total:       $total\n\n";
}

sub print_help {
    print <<_USAGE_;
import_borrowers.pl -c /path/to/borrowers.csv -m cardnumber
    -c --csv                            Path to the CSV file of patrons  to import
    -m --matchpoint                     Field on which to match incoming patrons to existing patrons
    -d --default                        Set defaults to patron fields, repeatable e.g. --default branchcode=MPL --default categorycode=PT
    -p --preserve-extended-atributes    Retain extended patron attributes for existing patrons being overwritten
    -o --overwrite                      Overwrite existing patrons with new data if a match is found
    -v --verbose                        Be verbose
_USAGE_
    exit;
}
