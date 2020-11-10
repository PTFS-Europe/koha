#!/usr/bin/perl

# Copyright 2011 BibLibre SARL
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

invoice.pl

=head1 DESCRIPTION

Invoice details

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Acquisition;
use C4::Budgets;
use C4::Log qw(logaction);

use Koha::Acquisition::Booksellers;
use Koha::Acquisition::Currencies;
use Koha::DateUtils;
use Koha::Misc::Files;
use Koha::Acquisition::Invoice::Adjustments;

my $input = new CGI;
my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => 'acqui/invoice.tt',
        query           => $input,
        type            => 'intranet',
        flagsrequired   => { 'acquisition' => '*' },
        debug           => 1,
    }
);

my $logged_in_patron = Koha::Patrons->find( $loggedinuser );
my $invoiceid = $input->param('invoiceid');
my $op        = $input->param('op');

output_and_exit( $input, $cookie, $template, 'insufficient_permission' )
  if $op
  && not $logged_in_patron->has_permission( { acquisition => 'edit_invoices' } );

my $invoice_files;
if ( C4::Context->preference('AcqEnableFiles') ) {
    $invoice_files = Koha::Misc::Files->new(
        tabletag => 'aqinvoices', recordid => $invoiceid );
}

if ( $op && $op eq 'close' ) {
    CloseInvoice($invoiceid);
    my $referer = $input->param('referer');
    if ($referer) {
        print $input->redirect($referer);
        exit 0;
    }
}
elsif ( $op && $op eq 'reopen' ) {
    output_and_exit( $input, $cookie, $template, 'insufficient_permission' )
        unless $logged_in_patron->has_permission( { acquisition => 'reopen_closed_invoices' } );

    ReopenInvoice($invoiceid);
    my $referer = $input->param('referer');
    if ($referer) {
        print $input->redirect($referer);
        exit 0;
    }
}
elsif ( $op && $op eq 'mod' ) {
    my $shipmentcost       = $input->param('shipmentcost');
    my $shipment_budget_id = $input->param('shipment_budget_id');
    my $invoicenumber      = $input->param('invoicenumber');
    ModInvoice(
        invoiceid             => $invoiceid,
        invoicenumber         => $invoicenumber,
        shipmentdate          => scalar output_pref( { str => scalar $input->param('shipmentdate'), dateformat => 'iso', dateonly => 1 } ),
        billingdate           => scalar output_pref( { str => scalar $input->param('billingdate'),  dateformat => 'iso', dateonly => 1 } ),
        shipmentcost          => $shipmentcost,
        shipmentcost_budgetid => $shipment_budget_id
    );
    if ($input->param('reopen')) {
        ReopenInvoice($invoiceid)
            if $logged_in_patron->has_permission( { acquisition => 'reopen_closed_invoices' } );
    } elsif ($input->param('close')) {
        CloseInvoice($invoiceid);
    } elsif ($input->param('merge')) {
        my @sources = $input->multi_param('merge');
        MergeInvoices($invoiceid, \@sources);
        defined($invoice_files) && $invoice_files->MergeFileRecIds(@sources);
    }
    $template->param( modified => 1 );
}
elsif ( $op && $op eq 'delete' ) {

    output_and_exit( $input, $cookie, $template, 'insufficient_permission' )
        unless $logged_in_patron->has_permission( { acquisition => 'delete_invoices' } );

    DelInvoice($invoiceid);
    defined($invoice_files) && $invoice_files->DelAllFiles();
    my $referer = $input->param('referer') || 'invoices.pl';
    if ($referer) {
        print $input->redirect($referer);
        exit 0;
    }
}
elsif ( $op && $op eq 'del_adj' ) {
    my $adjustment_id  = $input->param('adjustment_id');
    my $del_adj = Koha::Acquisition::Invoice::Adjustments->find( $adjustment_id );
    if ($del_adj) {
        if (C4::Context->preference("AcqLog")) {
            my $reason_length = length $del_adj->reason;
            my $reason_padded = ( ' ' x (80 - $reason_length) ) . $del_adj->reason;
            my $infos =
                sprintf("%010d", $del_adj->invoiceid) .
                sprintf("%010d", $del_adj->budget_id) .
                sprintf("%010d", $del_adj->encumber_open) .
                sprintf("%010.2f", $del_adj->adjustment) .
                $reason_padded;
            logaction(
                'ACQUISITIONS',
                'DELETE_INVOICE_ADJUSTMENT',
                $adjustment_id,
                $infos
            );
        }
        $del_adj->delete();
    }
}
elsif ( $op && $op eq 'mod_adj' ) {
    my @adjustment_id  = $input->multi_param('adjustment_id');
    my @adjustment     = $input->multi_param('adjustment');
    my @reason         = $input->multi_param('reason');
    my @note           = $input->multi_param('note');
    my @budget_id      = $input->multi_param('budget_id');
    my @encumber_open  = $input->multi_param('encumber_open');
    my %e_open = map { $_ => 1 } @encumber_open;

	my @keys = ('adjustment', 'reason', 'budget_id', 'encumber_open');
    for( my $i=0; $i < scalar @adjustment; $i++ ){
        if( $adjustment_id[$i] eq 'new' ){
            next unless ( $adjustment[$i] || $reason[$i] );
			my $adj = {
				invoiceid => $invoiceid,
                adjustment => $adjustment[$i],
                reason => $reason[$i],
                note => $note[$i],
                budget_id => $budget_id[$i] || undef,
                encumber_open => defined $e_open{ $adjustment_id[$i] } ? 1 : 0,
            };
			my $new_adj = Koha::Acquisition::Invoice::Adjustment->new($adj);
            $new_adj->store();
            # Log this addition
            if (C4::Context->preference("AcqLog")) {
                my $infos = get_log_string($adj);
                logaction(
                    'ACQUISITIONS',
                    'CREATE_INVOICE_ADJUSTMENT',
                    $new_adj->adjustment_id,
                    $infos
                );
            }
        }
        else {
            my $old_adj = Koha::Acquisition::Invoice::Adjustments->find( $adjustment_id[$i] );
            unless ( $old_adj->adjustment == $adjustment[$i] && $old_adj->reason eq $reason[$i] && $old_adj->budget_id == $budget_id[$i] && $old_adj->encumber_open == $e_open{$adjustment_id[$i]} && $old_adj->note eq $note[$i] ){
                # Log this modification
                if (C4::Context->preference("AcqLog")) {
                    my $infos = get_log_string({
                        adjustment        => $adjustment[$i],
                        reason            => $reason[$i],
                        budget_id         => $budget_id[$i],
                        encumber_open     => $e_open{$adjustment_id[$i]},
                        adjustment_old    => $old_adj->adjustment,
                        reason_old        => $old_adj->reason,
                        budget_id_old     => $old_adj->budget_id,
                        encumber_open_old => $old_adj->encumber_open
                    });
                    logaction(
                        'ACQUISITIONS',
                        'UPDATE_INVOICE_ADJUSTMENT',
                        $adjustment_id[$i],
                        $infos
                    );
                }
                $old_adj->timestamp(undef);
                $old_adj->adjustment( $adjustment[$i] );
                $old_adj->reason( $reason[$i] );
                $old_adj->note( $note[$i] );
                $old_adj->budget_id( $budget_id[$i] || undef );
                $old_adj->encumber_open( $e_open{$adjustment_id[$i]} ? 1 : 0 );
                $old_adj->update();
            }
        }
    }
}

my $details = GetInvoiceDetails($invoiceid);
my $bookseller = Koha::Acquisition::Booksellers->find( $details->{booksellerid} );
my @orders_loop = ();
my $orders = $details->{'orders'};
my @foot_loop;
my %foot;
my $shipmentcost = $details->{shipmentcost} || 0;
my $total_quantity = 0;
my $total_tax_excluded = 0;
my $total_tax_included = 0;
my $total_tax_value = 0;
foreach my $order (@$orders) {
    my $line = get_infos( $order, $bookseller);

    $line->{total_tax_excluded} = get_rounded_price($line->{unitprice_tax_excluded}) * $line->{quantity};
    $line->{total_tax_included} = get_rounded_price($line->{unitprice_tax_included}) * $line->{quantity};

    $line->{tax_value} = $line->{tax_value_on_receiving};
    $line->{tax_rate} = $line->{tax_rate_on_receiving};

    $foot{$$line{tax_rate}}{tax_rate} = $$line{tax_rate};
    $foot{$$line{tax_rate}}{tax_value} += get_rounded_price($$line{tax_value});
    $total_tax_value += $$line{tax_value};
    $foot{$$line{tax_rate}}{quantity}  += $$line{quantity};
    $total_quantity += $$line{quantity};
    $foot{$$line{tax_rate}}{total_tax_excluded} += get_rounded_price($$line{total_tax_excluded});
    $total_tax_excluded += get_rounded_price($$line{total_tax_excluded});
    $foot{$$line{tax_rate}}{total_tax_included} += get_rounded_price($$line{total_tax_included});
    $total_tax_included += get_rounded_price($$line{total_tax_included});

    $line->{orderline} = $line->{parent_ordernumber};
    push @orders_loop, $line;
}

push @foot_loop, map {$_} values %foot;

my $shipmentcost_budgetid = $details->{shipmentcost_budgetid};

# build budget list
my $budget_loop = [];
my $budgets     = GetBudgetHierarchy();
foreach my $r ( @{$budgets} ) {
    next unless ( CanUserUseBudget( $loggedinuser, $r, $flags ) );

    if ( !defined $r->{budget_amount} || $r->{budget_amount} == 0 ) {
        next;
    }

    my $selected = $shipmentcost_budgetid ? $r->{budget_id} eq $shipmentcost_budgetid : 0;

    push @{$budget_loop},
      {
        b_id     => $r->{budget_id},
        b_txt    => $r->{budget_name},
        b_active => $r->{budget_period_active},
        selected => $selected,
      };
}

@{$budget_loop} =
  sort { uc( $a->{b_txt} ) cmp uc( $b->{b_txt} ) } @{$budget_loop};

my $adjustments = Koha::Acquisition::Invoice::Adjustments->search({ invoiceid => $details->{'invoiceid'} });
if ( $adjustments ) { $template->param( adjustments => $adjustments ); }

$template->param(
    invoiceid                   => $details->{'invoiceid'},
    invoicenumber               => $details->{'invoicenumber'},
    suppliername                => $details->{'suppliername'},
    booksellerid                => $details->{'booksellerid'},
    shipmentdate                => $details->{'shipmentdate'},
    billingdate                 => $details->{'billingdate'},
    invoiceclosedate            => $details->{'closedate'},
    shipmentcost                => $shipmentcost,
    orders_loop                 => \@orders_loop,
    foot_loop                   => \@foot_loop,
    total_quantity              => $total_quantity,
    total_tax_excluded          => $total_tax_excluded,
    total_tax_included          => $total_tax_included,
    total_tax_value             => $total_tax_value,
    total_tax_excluded_shipment => $total_tax_excluded + $shipmentcost,
    total_tax_included_shipment => $total_tax_included + $shipmentcost,
    invoiceincgst               => $bookseller->invoiceincgst,
    currency                    => Koha::Acquisition::Currencies->get_active,
    budgets                     => $budget_loop,
    budget                      => GetBudget( $shipmentcost_budgetid ),
);

defined( $invoice_files ) && $template->param( files => $invoice_files->GetFilesInfo() );

# FIXME
# Fonction dupplicated from basket.pl
# Code must to be exported. Where ??
sub get_infos {
    my $order = shift;
    my $bookseller = shift;
    my $qty = $order->{'quantity'} || 0;
    if ( !defined $order->{quantityreceived} ) {
        $order->{quantityreceived} = 0;
    }
    my $budget = GetBudget( $order->{'budget_id'} );

    my %line = %{ $order };
    $line{order_received} = ( $qty == $order->{'quantityreceived'} );
    $line{budget_name}    = $budget->{budget_name};

    if ( $line{'title'} ) {
        my $volume      = $order->{'volume'};
        my $seriestitle = $order->{'seriestitle'};
        $line{'title'} .= " / $seriestitle" if $seriestitle;
        $line{'title'} .= " / $volume"      if $volume;
    }

    return \%line;
}

sub get_log_string {
    my ($data) = @_;

    # We specify the keys we're dealing for logging within an array in order
    # to preserve order, if we just iterate the hash keys, we could get
    # the values in any order
    my @keys = (
        'budget_id',
        'encumber_open',
        'budget_id_old',
        'encumber_open_old'
    );
    # Adjustment amount
    my $return = sprintf("%010.2f", $data->{adjustment});
    # Left pad "reason" to the maximum length of aqinvoice_adjustments.reason
    # (80 characters)
    my $reason_len = length $data->{reason};
    $return .= ( ' ' x (80 - $reason_len) ) . $data->{reason};
    # Append the remaining fields
    foreach my $key(@keys) {
        $return .= sprintf("%010d", $data->{$key});
    }
    # Old adjustment amount
    $return .= sprintf("%010.2f", $data->{adjustment_old});
    # Left pad "reason_old" to the maximum length of aqinvoice_adjustments.reason
    # (80 characters)
    my $reason_old_len = length $data->{reason_old};
    $return .= ( ' ' x (80 - $reason_old_len) ) . $data->{reason_old};
    return $return;
}

output_html_with_http_headers $input, $cookie, $template->output;
