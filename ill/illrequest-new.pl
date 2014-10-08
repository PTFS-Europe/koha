#!/usr/bin/perl

# Copyright (c) 2013 Mark Gavillet & PTFS Europe Ltd
# Copyright (c) 2014 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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
use C4::Auth;
use C4::Output;
use CGI;
use Koha::Borrowers;
use C4::Members qw( GetMemberDetails GetPatronImage);
use C4::ILL qw( GetILLAuthValues LogILLRequest );

my $query = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'ill/illrequest-new.tt',
        query           => $query,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { ill => 1 },
    }
);

my $borrowernumber = $query->param('borrowernumber');
my $borrower       = GetMemberDetails($borrowernumber);
$template->param($borrower);
#my ( $picture, $dberror ) = GetPatronImage( $borrower->{cardnumber} );
#if ($picture) {
#    $template->param( picture => 1 );
#}

my $requestnumber;
if ( $query->param('request_type') ) {
    $requestnumber = LogILLRequest( $borrowernumber, $query );
}

my $illoptions;
if ( !$query->param('illtype') ) {
    $illoptions = GetILLAuthValues('ILLTYPE');
}

my $borrower    = Koha::Borrowers->new()->Find( { borrowernumber => $borrowernumber });
my $remainingrequests = $borrower->Category()->illlimit - $borrower->ILLRequests()->Count();

$template->param(
    RemainingRequests => $remainingrequests,
    RequestNumber     => $requestnumber,
    illtype           => $query->param('illtype'),
    illoptions        => $illoptions,
    borrowernumber    => $borrowernumber,
    local1            => C4::Context->preference('ILLLocalField1'),
    local2            => C4::Context->preference('ILLLocalField2'),
    local3            => C4::Context->preference('ILLLocalField3'),
);
$template->param( %{$borrower} );

output_html_with_http_headers( $query, $cookie, $template->output );
