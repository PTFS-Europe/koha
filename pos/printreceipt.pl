#!/usr/bin/perl

# Copyright 2019 PTFS Europe
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

use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Letters;
use Koha::Account::Lines;
use Koha::DateUtils;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "pos/printreceipt.tt",
        query           => $input,
        type            => "intranet",
    }
);

my $payment_id = $input->param('accountlines_id');
my $payment    = Koha::Account::Lines->find($payment_id);
my $patron     = $payment->patron;

my $logged_in_user = Koha::Patrons->find($loggedinuser) or die "Not logged in";
output_and_exit_if_error(
    $input, $cookie,
    $template,
    {
        module         => 'members',
        logged_in_user => $logged_in_user,
        current_patron => $patron
    }
) if $patron;    # Payment could have been anonymous

my $letter = C4::Letters::getletter( 'pos', 'RECEIPT',
    C4::Context::mybranch, 'print', $patron->lang );

$template->param(
    letter  => $letter,
    payment => $payment,

    tendered => scalar $input->param('tendered'),
    change   => scalar $input->param('change')
);

output_html_with_http_headers $input, $cookie, $template->output;
