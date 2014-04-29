#!/usr/bin/perl

# Copyright (c) 2014 PTFS Europe Ltd
# Copyright (c) 2013 Mark Gavillet & PTFS Europe
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
use C4::Members qw( GetPatronImage GetMember);
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::ILL qw(ILLRequests_by_borrower);

my $input = CGI->new();

my $borrowernumber = $input->param('borrowernumber');

#get borrower details
my $borrower = GetMember( borrowernumber => $borrowernumber );

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'members/illrequests.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => 1,
    }
);

$template->param($borrower);
my ( $picture, $dberror ) = GetPatronImage( $borrower->{'cardnumber'} );
if ($picture) {
    $template->param( picture => 1 );
}

# Getting the requests
#my @illrequests = GetMyILL($borrowernumber);
my $illrequests = ILLRequests_by_borrower($borrowernumber);
$template->param( %{$borrower} );

if ( C4::Context->preference('ExtendedPatronAttributes') ) {
    my $attributes = GetBorrowerAttributes($borrowernumber);
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes       => $attributes
    );
}

$template->param(
    ILLRequests    => $illrequests,
    borrowernumber => $borrowernumber,
    ill            => 1,
);
output_html_with_http_headers( $input, $cookie, $template->output );
