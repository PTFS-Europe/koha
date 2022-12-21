#!/usr/bin/perl

# Copyright Koustubha Kale 2010
# Copyright PTFS Europe 2020
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

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_and_exit_if_error output_and_exit output_html_with_http_headers );
use CGI qw ( -utf8 );
use C4::Letters;
use Koha::Account::Lines;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "members/printfeercpt.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => {
            borrowers     => 'edit_borrowers',
            updatecharges => 'remaining_permissions'
        }
    }
);

my $credit_id = $input->param('accountlines_id');
my $credit    = Koha::Account::Lines->find($credit_id);
my $patron    = $credit->patron;

my $logged_in_user = Koha::Patrons->find($loggedinuser) or die "Not logged in";
output_and_exit_if_error(
    $input, $cookie,
    $template,
    {
        module         => 'members',
        logged_in_user => $logged_in_user,
        current_patron => $patron
    }
);

my $letter = C4::Letters::GetPreparedLetter(
    module                 => 'circulation',
    letter_code            => 'CREDIT_' . $credit->credit_type_code,
    branchcode             => C4::Context::mybranch,
    message_transport_type => 'print',
    lang                   => $patron->lang,
    tables                 => {
        credits   => $credit_id,
        borrowers => $patron->borrowernumber
    },
    substitute => {
        tendered => scalar $input->param('tendered'),
        change   => scalar $input->param('change')
    }
);

$letter //= C4::Letters::GetPreparedLetter(
    module                 => 'circulation',
    letter_code            => 'ACCOUNT_CREDIT',
    branchcode             => C4::Context::mybranch,
    message_transport_type => 'print',
    lang                   => $patron->lang,
    tables                 => {
        credits   => $credit_id,
        borrowers => $patron->borrowernumber
    },
    substitute => {
        tendered => scalar $input->param('tendered'),
        change   => scalar $input->param('change')
    }
);

$template->param(
    slip   => $letter->{content},
    plain  => !$letter->{is_html},
    patron => $patron,
);

output_html_with_http_headers $input, $cookie, $template->output;
