#!/usr/bin/perl

# Copyright PTFS Europe 2021
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

use CGI qw ( -utf8 );

use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user );

my $input = CGI->new;
my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user(
    {
        template_name => "bookings/list.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { circulate => 'manage_bookings' },
    }
);

my $biblionumber = $input->param('biblionumber');
my $biblio       = Koha::Biblios->find($biblionumber);

$template->param(
    biblionumber => $biblionumber,
    biblio       => $biblio,
    bookingsview => 1,
);

output_html_with_http_headers $input, $cookie, $template->output;
