#!/usr/bin/perl

# Copyright 2013 PTFS-Europe Ltd and Mark Gavillet
# Copyright 2014 PTFS-Europe Ltd
#
# This file is part of Koha.
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
use CGI;
use C4::Auth;
use C4::Output;
use C4::Search qw(GetDistinctValues);
use C4::ILL qw( GetAllILL);
use C4::Context;

my $input = CGI->new;
my $request_type;
if ( !$input->param('request_type') ) {
    $request_type = 'ALL';
}
else {
    $request_type = $input->param('request_type');
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => 'ill/ill-requests.tt',
        query         => $input,
        type          => 'intranet',
        flagsrequired => { ill => 1 },
    }
);

#my $currentstatusloop = GetDistinctValues('illrequest.status');
$template->param( allillrequests => GetAllILL($request_type) );

#$template->param( fullstatusloop    => $fullstatus );
#$template->param( currentstatusloop => $currentstatusloop );
$template->param( request_type => $request_type );
$template->param(
    new_status => C4::Context->preference('ILLNewRequestStatus') );

output_html_with_http_headers( $input, $cookie, $template->output );
