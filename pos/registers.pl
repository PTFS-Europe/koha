#!/usr/bin/perl
#
# c 2020 PTFS-Europe Ltd
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
use C4::Context;

use Koha::Cash::Registers;
use Koha::Database;

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'pos/registers.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
    }
);
my $logged_in_user = Koha::Patrons->find($loggedinuser) or die "Not logged in";

my $library = Koha::Libraries->find( C4::Context->userenv->{'branch'} );
$template->param( library => $library );

my $registers = Koha::Cash::Registers->search(
    { branch   => $library->id, archived => 0 },
    { order_by => { '-asc' => 'name' } }
);

if ( !$registers->count ) {
    $template->param( error_registers => 1 );
}
else {
    $template->param( registers => $registers );
}

my $op = $input->param('op') // '';
if ( $op eq 'cashup' ) {
    for my $register ( $registers->as_list ) {
        $register->add_cashup(
            {
                user_id => $logged_in_user->id,
                amount  => $register->outstanding_accountlines->total
            }
        );
    }
}

output_html_with_http_headers( $input, $cookie, $template->output );
