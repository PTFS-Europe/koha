#!/usr/bin/perl

# Copyright 2013 ByWater Solutions
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

use CGI;

use C4::Auth;
use C4::Output;
use Koha::Clubs;

my $cgi = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "clubs/enroll.tt",
        query           => $cgi,
        type            => "opac",
        authnotrequired => 0,
    }
);

my $id             = $cgi->param('id');
my $borrowernumber = $cgi->param('borrowernumber');

my $club = Koha::Clubs->find($id);

$template->param(
    club           => $club,
    borrowernumber => $borrowernumber,
);

output_html_with_http_headers( $cgi, $cookie, $template->output, undef, { force_no_caching => 1 } );
