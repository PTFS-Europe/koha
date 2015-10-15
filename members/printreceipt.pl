#!/usr/bin/perl

# Copyright 2015 PTFS-Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Dates qw/format_date/;
use CGI;
use C4::Members qw( GetMember GetMemberAccountRecords);
use C4::Branch qw( GetBranch GetBranchName GetBranches);
use Koha::Till;

my $q = CGI->new();
my $branch = GetBranch( $q, GetBranches() );

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'members/printreceipt.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired =>
          { borrowers => 1, updatecharges => 'remaining_permissions' },
    }
);

my $borrowernumber = $q->param('borrowernumber');
my $change         = $q->param('change');
my $tendered       = $q->param('tendered');
my $tillid         = $q->param('tillid');
if ( !$tillid ) {
    my $sessionID = $q->cookie('CGISESSID');
    my $session   = get_session($sessionID);

    $tillid = Koha::Till->branch_tillid($branch);
}
my $timestamp = $q->param('paymenttime');
my %accts_hash = map { $_ => 1 } split /,/, $q->param('accountlines_id');

#get borrower details
my $borrower = GetMember( 'borrowernumber' => $borrowernumber );

#get account details
my ( $total, $accts, $numaccts ) = GetMemberAccountRecords($borrowernumber);
my $totalcredit;
if ( $total <= 0 ) {
    $totalcredit = 1;
}
my $accts_to_print = [];

for my $acctline ( @{$accts} ) {
    if ( exists $accts_hash{ $acctline->{accountlines_id} } ) {

        my $amountcredit = 0;
        if ( !defined $acctline->{amount} ) {
            $acctline->{amount} = 0;
        }
        elsif ( $acctline->{amount} < 0 ) {
            $amountcredit = 1;
            $acctline->{amount} *= -1;    # display credit as a +ve amt
        }

        push @{$accts_to_print},
          {
            date         => format_date( $acctline->{date} ),
            accounttype  => $acctline->{accountline},
            description  => $acctline->{description},
            amountcredit => $amountcredit,
            amount       => sprintf '%.2f',
            $acctline->{amount},
          };
    }
}

$template->param(
    branchname  => GetBranchName($branch),
    total       => $total,
    totalcredit => $totalcredit,
    change      => $change,
    tendered    => $tendered,
    accounts    => $accts_to_print,
    receiptid   => "$tillid-$timestamp",
);

output_html_with_http_headers( $q, $cookie, $template->output );
