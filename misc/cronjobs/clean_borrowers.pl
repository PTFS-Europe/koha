#!/usr/bin/perl

# Copyright 2018, PTFS Europe.
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
use Carp;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use Koha::Database;
use Koha::Patrons;
use DateTime;

use Getopt::Long;
use C4::Log;

sub usage {
    print STDERR <<USAGE;
Usage: $0  --days_since_expired DAYS  [-h|--help]

   --days_since_expired DAYS     delete patrons that expired more than than DAYS expired.
   --days_since_issued DAYS      delete patrons that were last issued items more than DAYS ago.
   --days_since_seen DAYS        delete patrons that have not been seen for DAYS.
   --on_list ID                  delete patrons on list with ID.
   --zero_current_issues TRUE    delete patrons without any current issues.
   --owes_less_than BILL         delete patrons only if they have less than BILL left in 
                                 outstanding fees.
   --at_branch CODE              delete patrons only if they belong to branch with CODE
   --in_category CODE            delete patrons only if they belong to category with CODE
   -m --mode archive|delete      specifies action to take, defaults to archive if not set
   -v --verbose                  gives a little more information
   -h --help                     prints this help message, and exits, ignoring all
                                 other options
USAGE
    exit $_[0];
}

my (
    $help,   $expired,  $outstanding, $issued,  $seen,
    $branch, $category, $list,        $confirm, $verbose
);
my $mode   = 'archive';
my $issues = 0;

GetOptions(
    'h|help'                => \$help,
    'days_since_expired:i'  => \$expired,
    'days_since_issued:i'   => \$issued,
    'days_since_seen:i'     => \$seen,
    'on_list:i'             => \$list,
    'zero_current_issues:i' => \$issues,
    'owes_less_than:i'      => \$outstanding,
    'at_branch:s'           => \$branch,
    'in_category:s'         => \$category,
    'm|mode:s'              => \$mode,
    'c|confirm'             => \$confirm,
    'v|verbose'             => \$verbose,
) || usage(1);

if ($help) {
    usage(0);
}

if (   !$expired
    && !$issued
    && !$seen
    && !$outstanding
    && !$issues
    && !$branch
    && !$category )
{
    print "At least one filter parameter should be specified.\n\n";
    usage(1);
}

if ( ( $mode ne 'archive' ) && ( $mode ne 'delete' ) ) {
    print "Mode must be either 'archive' or 'delete'.\n\n";
    usage(1);
}

cronlogaction();

my $tz = C4::Context->tz;
my $now = DateTime->now( time_zone => $tz );

my $guarantorList = Koha::Patrons->search(
    { guarantorid => [ { '!=' => 0 }, { '!=' => undef } ] },
    { select      => ['borrowernumber'] } )->_resultset->as_query;

my $dtf   = Koha::Database->new->schema->storage->datetime_parser;
my $attr  = {};
my $where = {
    '-and' => [
        {
            # Limit by those that are not guarantors
            'me.borrowernumber' => { '-not_in' => $guarantorList }
        }
    ]
};

# Limit to patrons without any current issues
if ( !$issues ) {
    push @{ $attr->{'+select'} },
      { max => 'issues.timestamp', '-as' => 'currentissue' };
    push @{ $attr->{'+as'} }, 'currentissue';
    push @{ $attr->{'having'}->{'-and'} }, { 'currentissue' => undef };
}

# Limit to patrons expired more than X days
if ($expired) {
    my $expired_before = $now->clone->subtract( days => $expired );
    push @{ $where->{'-and'} },
      { 'dateexpiry' => { '<' => $dtf->format_datetime($expired_before) } };
}

# Limit to patrons not issued to for at least X days
if ($issued) {
    my $issued_before = $now->clone->subtract( days => $issued );
    push @{ $attr->{'join'} }, ( 'issues', 'old_issues' );
    push @{ $attr->{'+select'} },
      { max => 'old_issues.timestamp', '-as' => 'lastissue' };
    push @{ $attr->{'+as'} }, 'lastissue';
    push @{ $attr->{'having'}->{'-and'} },
      { 'lastissue' => { '<' => $dtf->format_datetime($issued_before) } };
}

# Limit to patrons not owing more than X in fines
if ( defined($outstanding) ) {
    push @{ $attr->{'join'} }, 'accountlines';
    push @{ $attr->{'+select'} },
      { sum => 'accountlines.amountoutstanding', '-as' => 'outstanding' };
    push @{ $attr->{'+as'} }, 'outstanding';
    push @{ $attr->{'having'}->{'-and'} },
      { outstanding => { '<=' => $outstanding } };
}

# Limit to patrons not seen for at least X days
if ($seen) {
    my $last_seen = $now->clone->subtract( days => $seen );
    push @{ $where->{'-and'} },
      { lastseen => { '<' => $dtf->format_datetime($last_seen) } };
}

# Limit to patrons enrolled at branch X
if ($branch) {
    push @{ $where->{'-and'} }, { branchcode => $branch };
}

# Limit to patrons belonging to category X
if ($category) {
    push @{ $where->{'-and'} }, { categorycode => $category };
}

# Limit to patrons on patron list X
if ($list) {
    push @{ $attr->{'join'} }, 'patron_list_patrons';
    push @{ $where->{'-and'} },
      { 'patron_list_patrons.patron_list_id' => $list };
}

# Group by borrowernumber
$attr->{group_by} = 'me.borrowernumber';

# Run Query
my $toDelete = Koha::Patrons->search( $where, $attr );
$verbose
  and print $toDelete->count
  . " patrons selected to "
  . ( $mode eq 'archive' ? "archive" : "delete" ) . "\n";

# Do Delete
if ($confirm) {
    my $count = 0;
    for my $patron ( $toDelete->as_list ) {
        my $borrowernumber = $patron->borrowernumber;
        if ( $mode eq 'archive' ) {
            my $deleted = eval { $patron->move_to_deleted; };
            if ( $@ or not $deleted ) {
                $verbose
                  and print
                  "Failed to delete patron $borrowernumber, cannot move it"
                  . ( $@ ? ": ($@)" : "" ) . "\n";
                next;
            }
        }

        eval { $patron->delete };
        if ($@) {
            $verbose
              and print "Failed to delete patron $borrowernumber: $@)\n";
            next;
        }
        $verbose and print "Deleted user $borrowernumber\n";
        $count++;
    }
    $verbose
      and print $count
      . " users "
      . ( $mode eq 'archive' ? "archived" : "deleted" ) . "\n";
}

exit(0);
