#!/usr/bin/perl


#written 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details


# Copyright 2000-2002 Katipo Communications
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

use C4::Auth;
use C4::Output;
use CGI qw ( -utf8 );
use C4::Members;
use C4::Accounts;
use Koha::Cash::Registers;
use Koha::Patrons;
use Koha::Patron::Categories;

my $input=new CGI;


my ($template, $loggedinuser, $cookie) = get_template_and_user(
    {
        template_name   => "members/boraccount.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { borrowers     => 'edit_borrowers',
                             updatecharges => 'remaining_permissions'},
        debug           => 1,
    }
);

my $schema         = Koha::Database->new->schema;
my $borrowernumber = $input->param('borrowernumber');
my $payment_id     = $input->param('payment_id');
my $change_given   = $input->param('change_given');
my $action         = $input->param('action') || '';

my $logged_in_user = Koha::Patrons->find( $loggedinuser ) or die "Not logged in";
my $library_id = C4::Context->userenv->{'branch'};
my $patron = Koha::Patrons->find( $borrowernumber );
unless ( $patron ) {
    print $input->redirect("/cgi-bin/koha/circ/circulation.pl?borrowernumber=$borrowernumber");
    exit;
}

output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

my $registerid;
if ( C4::Context->preference('UseCashRegisters') ) {
    $registerid = scalar $input->param('registerid');
    my $registers  = Koha::Cash::Registers->search(
        { branch   => $library_id, archived => 0 },
        { order_by => { '-asc' => 'name' } }
    );

    if ( !$registers->count ) {
        $template->param( error_registers => 1 );
    }
    else {

        if ( !$registerid ) {
            my $default_register = Koha::Cash::Registers->find(
                { branch => $library_id, branch_default => 1 } );
            $registerid = $default_register->id if $default_register;
        }
        $registerid = $registers->next->id if !$registerid;

        $template->param(
            registerid => $registerid,
            registers  => $registers,
        );
    }
}

if ( $action eq 'void' ) {
    my $payment_id = scalar $input->param('accountlines_id');
    my $payment    = Koha::Account::Lines->find( $payment_id );
    $payment->void();
}

if ( $action eq 'payout' ) {
    my $payment_id        = scalar $input->param('accountlines_id');
    my $payment           = Koha::Account::Lines->find($payment_id);
    my $amount           = scalar $input->param('amount');
    my $transaction_type = scalar $input->param('transaction_type');
    $schema->txn_do(
        sub {
            my $payout = $payment->payout(
                {
                    payout_type   => $transaction_type,
                    branch        => $library_id,
                    staff_id      => $logged_in_user->id,
                    cash_register => $registerid,
                    interface     => 'intranet',
                    amount        => $amount
                }
            );
        }
    );
}

if ( $action eq 'refund' ) {
    my $charge_id        = scalar $input->param('accountlines_id');
    my $charge           = Koha::Account::Lines->find($charge_id);
    my $amount           = scalar $input->param('amount');
    my $transaction_type = scalar $input->param('transaction_type');
    $schema->txn_do(
        sub {

            my $refund = $charge->reduce(
                {
                    reduction_type => 'REFUND',
                    branch         => $library_id,
                    staff_id       => $logged_in_user->id,
                    interface      => 'intranet',
                    amount         => $amount
                }
            );
            unless ( $transaction_type eq 'AC' ) {
                my $payout = $refund->payout(
                    {
                        payout_type   => $transaction_type,
                        branch        => $library_id,
                        staff_id      => $logged_in_user->id,
                        cash_register => $registerid,
                        interface     => 'intranet',
                        amount        => $amount
                    }
                );
            }
        }
    );
}

if ( $action eq 'discount' ) {
    my $charge_id        = scalar $input->param('accountlines_id');
    my $charge           = Koha::Account::Lines->find($charge_id);
    my $amount           = scalar $input->param('amount');
    $schema->txn_do(
        sub {

            my $discount = $charge->reduce(
                {
                    reduction_type => 'DISCOUNT',
                    branch         => $library_id,
                    staff_id       => $logged_in_user->id,
                    interface      => 'intranet',
                    amount         => $amount
                }
            );
        }
    );
}

#get account details
my $total = $patron->account->balance;

my @accountlines = Koha::Account::Lines->search(
    { borrowernumber => $patron->borrowernumber },
    { order_by       => { -desc => 'accountlines_id' } }
);

my $totalcredit;
if($total <= 0){
        $totalcredit = 1;
}

$template->param(
    patron              => $patron,
    finesview           => 1,
    total               => sprintf("%.2f",$total),
    totalcredit         => $totalcredit,
    accounts            => \@accountlines,
    payment_id          => $payment_id,
    change_given        => $change_given,
);

output_html_with_http_headers $input, $cookie, $template->output;
