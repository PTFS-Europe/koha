#!/usr/bin/perl


#script to receive orders
#written by chris@katipo.co.nz 24/2/2000

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

=head1 NAME

orderreceive.pl

=head1 DESCRIPTION

This script shows all order already receive and all pendings orders.
It permit to write a new order as 'received'.

=head1 CGI PARAMETERS

=over 4

=item booksellerid

to know on what supplier this script has to display receive order.

=item invoiceid

the id of this invoice.

=item freight

=item biblio

The biblionumber of this order.

=item datereceived

=item catview

=item gst

=back

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Context;
use C4::Acquisition qw( GetInvoice );
use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Budgets qw( GetBudget GetBudgetPeriods GetBudgetPeriod GetBudgetHierarchy CanUserUseBudget );
use C4::Members;
use C4::Biblio qw( GetMarcStructure );
use C4::Suggestions qw( GetSuggestion GetSuggestionInfoFromBiblionumber GetSuggestionInfo );

use Koha::Acquisition::Booksellers;
use Koha::Acquisition::Currencies qw( get_active );
use Koha::Acquisition::Orders;
use Koha::DateUtils qw( dt_from_string );
use Koha::I18N;
use Koha::ItemTypes;
use Koha::Patrons;

my $input      = CGI->new;

my $dbh          = C4::Context->dbh;
my $invoiceid    = $input->param('invoiceid');
my $invoice      = GetInvoice($invoiceid);
my $booksellerid   = $invoice->{booksellerid};
my $freight      = $invoice->{shipmentcost};
my $ordernumber  = $input->param('ordernumber');

my $bookseller = Koha::Acquisition::Booksellers->find( $booksellerid );
my $order = Koha::Acquisition::Orders->find( $ordernumber );

my ( $template, $loggedinuser, $cookie, $userflags ) = get_template_and_user(
    {
        template_name   => "acqui/orderreceive.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => {acquisition => 'order_receive'},
    }
);

unless ( $order ) {
    output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

# prepare the form for receiving
my $basket = $order->basket;
my $currencies = Koha::Acquisition::Currencies->search;
my $active_currency = $currencies->get_active;

# Check if ACQ framework exists
my $acq_fw = GetMarcStructure( 1, 'ACQ', { unsafe => 1 } );
unless($acq_fw) {
    $template->param('NoACQframework' => 1);
}

my $creator = Koha::Patrons->find( $order->created_by );

my $budget = GetBudget( $order->budget_id );

my $datereceived = $order->datereceived ? dt_from_string( $order->datereceived ) : dt_from_string;

# get option values for TaxRates syspref
my @gst_values = map {
    option => $_ + 0.0
}, split( '\|', C4::Context->preference("TaxRates") );

my $order_internalnote = $order->order_internalnote;
my $order_vendornote   = $order->order_vendornote;
if ( $order->subscriptionid ) {
    # Order from a subscription, we will display an history of what has been received
    my $orders = Koha::Acquisition::Orders->search(
        {
            subscriptionid     => $order->subscriptionid,
            parent_ordernumber => $order->ordernumber,
            ordernumber        => { '!=' => $order->ordernumber }
        }
    );
    if ( $order->parent_ordernumber != $order->ordernumber ) {
        my $parent_order = Koha::Acquisition::Orders->find($order->parent_ordernumber);
        $order_internalnote = $parent_order->order_internalnote;
        $order_vendornote   = $parent_order->order_vendornote;
    }
    $template->param(
        orders => $orders,
    );
}

$template->param(
    order                 => $order,
    freight               => $freight,
    name                  => $bookseller->name,
    active_currency       => $active_currency,
    currencies            => $currencies->search({ rate => { '!=' => 1 } }),
    invoiceincgst         => $bookseller->invoiceincgst,
    bookfund              => $budget->{budget_name},
    creator               => $creator,
    invoiceid             => $invoice->{invoiceid},
    invoice               => $invoice->{invoicenumber},
    datereceived          => $datereceived,
    order_internalnote    => $order_internalnote,
    order_vendornote      => $order_vendornote,
    gst_values            => \@gst_values,
);

my $suggestion = GetSuggestionInfoFromBiblionumber($order->biblionumber);
if ( $suggestion ) {
    $template->param( suggestion => $suggestion );
}

my $patron = Koha::Patrons->find( $loggedinuser )->unblessed;
my @budget_loop;
my $periods = GetBudgetPeriods( );
foreach my $period (@$periods) {
    if ($period->{'budget_period_id'} == $budget->{'budget_period_id'}) {
        $template->{'VARS'}->{'budget_period_description'} = $period->{'budget_period_description'};
    }
    next if $period->{'budget_period_locked'} || !$period->{'budget_period_description'};
    my $budget_hierarchy = GetBudgetHierarchy( $period->{'budget_period_id'} );
    my @funds;
    foreach my $r ( @{$budget_hierarchy} ) {
        next unless ( CanUserUseBudget( $patron, $r, $userflags ) );
        if ( !defined $r->{budget_amount} || $r->{budget_amount} == 0 ) {
            next;
        }
        push @funds,
          {
            b_id  => $r->{budget_id},
            b_txt => $r->{budget_name},
            b_sel => ( $r->{budget_id} == $order->budget_id ) ? 1 : 0,
          };
    }

    @funds = sort { uc( $a->{b_txt} ) cmp uc( $b->{b_txt} ) } @funds;

    push @budget_loop,
      {
        'id'          => $period->{'budget_period_id'},
        'description' => $period->{'budget_period_description'},
        'funds'       => \@funds
      };
}

$template->{'VARS'}->{'budget_loop'} = \@budget_loop;

my $op = $input->param('op');
if ($op and $op eq 'edit'){
    $template->param(edit   =>   1);
}
output_html_with_http_headers $input, $cookie, $template->output;
