#!/usr/bin/perl

# Copyright 2012 Mark Gavillet & PTFS Europe
# Copyright 2014 PTFS Europe Ltd
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

use CGI;

use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Output;
use Koha::Borrowers;

my $query = CGI->new();

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'opac-ill.tt',
        query           => $query,
        type            => 'opac',
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $borrower = Koha::Borrower->new()->Find( { borrowernumber => $borrowernumber } );
my @requests = $borrower->ILLRequests();
$template->param( ILLRequests => \@requests );

output_html_with_http_headers( $query, $cookie, $template->output );
