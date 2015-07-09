#!/usr/bin/perl
#
# Copyright 2015 PTFS Europe
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
use C4::Branch qw( GetBranchesLoop);
use C4::Koha;
use C4::Context;
use C4::Output;

my $cgi = CGI->new();
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/tills.tt',
        query           => $cgi,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { admin => 'edit_tills' },
        debug           => 1,
    }
);

$template->param( branch_list => GetBranchesLoop() );

output_html_with_http_headers $cgi, $cookie, $template->output;
