package Koha::EDI;

# Copyright 2014 PTFS-Europe Ltd
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

use strict;
use warnings;
use base qw(Exporter);
use Carp;
use English qw{ -no_match_vars };
use Business::ISBN;
use DateTime;
use C4::Context;
use Koha::Database;
use C4::Acquisition qw( NewBasket AddInvoice ModReceiveOrder );
use C4::Items qw(AddItem);
use C4::Biblio qw( AddBiblio TransformKohaToMarc GetMarcBiblio );
use Koha::Edifact::Order;
use Koha::Edifact;
use Log::Log4perl;

our $VERSION = 1.1;
our @EXPORT_OK =
  qw( process_quote process_invoice create_edi_order get_edifact_ean );

sub create_edi_order {
    my $parameters = shift;
    my $basketno   = $parameters->{basketno};
    my $ean        = $parameters->{ean};
    my $branchcode = $parameters->{branchcode};
    my $noingest   = $parameters->{noingest};
    $ean ||= C4::Context->preference('EDIfactEAN');
    if ( !$basketno || !$ean ) {
        carp 'create_edi_order called with no basketno or ean';
        return;
    }

    my $database = Koha::Database->new();
    my $schema   = $database->schema();

    my @orderlines = $schema->resultset('Aqorder')->search(
        {
            basketno    => $basketno,
            orderstatus => 'new',
        }
    )->all;

    my $vendor = $schema->resultset('VendorEdiAccount')->search(
        {
            vendor_id => $orderlines[0]->basketno->booksellerid->id,
        }
    )->single;

    my $ean_search_keys = { ean => $ean, };
    if ($branchcode) {
        $ean_search_keys->{branchcode} = $branchcode;
    }
    my $ean_obj =
      $schema->resultset('EdifactEan')->search($ean_search_keys)->single;

    my $edifact = Koha::Edifact::Order->new(
        { orderlines => \@orderlines, vendor => $vendor, ean => $ean_obj } );
    if ( !$edifact ) {
        return;
    }

    my $order_file = $edifact->encode();

    # ingest result
    if ($order_file) {
        if ($noingest) {    # allows scripts to produce test files
            return $order_file;
        }
        my $order = {
            message_type  => 'ORDERS',
            raw_msg       => $order_file,
            vendor_id     => $vendor->vendor_id,
            status        => 'Pending',
            basketno      => $basketno,
            filename      => $edifact->filename(),
            transfer_date => $edifact->msg_date_string(),
            edi_acct      => $vendor->id,

        };
        $schema->resultset('EdifactMessage')->create($order);
        return 1;
    }

    return;
}

sub process_invoice {
    my $invoice_message = shift;
    my $database        = Koha::Database->new();
    my $schema          = $database->schema();
    my $vendor_acct;
    my $logger = Log::Log4perl->get_logger();
    my $edi =
      Koha::Edifact->new( { transmission => $invoice_message->raw_msg, } );
    my $messages = $edi->message_array();
    if ( @{$messages} ) {

        # BGM contains an invoice number
        foreach my $msg ( @{$messages} ) {
            my $invoicenumber  = $msg->docmsg_number();
            my $shipmentcharge = $msg->shipment_charge();
            my $msg_date       = $msg->message_date;
            my $tax_date       = $msg->tax_point_date;
            if ( !defined $tax_date || $tax_date !~ m/^\d{8}/xms ) {
                $tax_date = $msg_date;
            }

            my $vendor_ean = $msg->supplier_ean;
            if ( !defined $vendor_acct || $vendor_ean ne $vendor_acct->san ) {
                $vendor_acct = $schema->resultset('VendorEdiAccount')->search(
                    {
                        san => $vendor_ean,
                    }
                )->single;
            }
            if ( !$vendor_acct ) {
                carp
"Cannot find vendor with ean $vendor_ean for invoice $invoicenumber in $invoice_message->filename";
                next;
            }
            $invoice_message->edi_acct( $vendor_acct->id );
            $logger->trace("Adding invoice:$invoicenumber");
            my $invoiceid = AddInvoice(
                invoicenumber         => $invoicenumber,
                booksellerid          => $invoice_message->vendor_id,
                shipmentdate          => $msg_date,
                billingdate           => $tax_date,
                shipmentcost          => $shipmentcharge,
                shipmentcost_budgetid => $vendor_acct->shipment_budget,
                message_id            => $invoice_message->id,
            );
            $logger->trace("Added as invoiceno :$invoiceid");
            my $lines = $msg->lineitems();

            foreach my $line ( @{$lines} ) {
                my $ordernumber = $line->ordernumber;
                $logger->trace( "Receipting order:$ordernumber Qty: ",
                    $line->quantity );

                # handle old basketno/ordernumber references
                if ( $ordernumber =~ m{\d+\/(\d+)}xms ) {
                    $ordernumber = $1;
                }
                my $order = $schema->resultset('Aqorder')->find($ordernumber);

      # ModReceiveOrder does not validate that $ordernumber exists validate here
                if ($order) {
                    ModReceiveOrder(
                        {
                            biblionumber         => $order->biblionumber,
                            ordernumber          => $ordernumber,
                            quantityreceived     => $line->quantity,
                            cost                 => $line->price_net,
                            invoiceid            => $invoicenumber,
                            datereceived         => $msg_date,
                            received_itemnumbers => [],
                        }
                    );
                }
                else {
                    $logger->error(
                        "No order found for $ordernumber Invoice:$invoicenumber"
                    );
                    next;
                }

            }

        }
    }

    $invoice_message->status('received');
    $invoice_message->update;    # status and basketno link
    return;
}

# called on messages with status 'new'
sub process_quote {
    my $quote = shift;

    my $edi = Koha::Edifact->new( { transmission => $quote->raw_msg, } );
    my $messages = $edi->message_array();
    my $process_errors = 0;
    my $logger         = Log::Log4perl->get_logger();
    my $database       = Koha::Database->new();
    my $schema         = $database->schema();

    if ( @{$messages} && $quote->vendor_id ) {
        my $basketno =
          NewBasket( $quote->vendor_id, 0, $quote->filename, q{}, q{} . q{} );
        $quote->basketno($basketno);
        $logger->trace("Created basket :$basketno");
        for my $msg ( @{$messages} ) {
            my $items  = $msg->lineitems();
            my $refnum = $msg->message_refno;

            for my $item ( @{$items} ) {
                if ( !quote_item( $schema, $item, $quote, $basketno ) ) {
                    ++$process_errors;
                }
            }
        }
    }
    my $status = 'received';
    if ($process_errors) {
        $status = 'error';
    }

    $quote->status($status);
    $quote->update;    # status and basketno link

    return;
}

sub quote_item {
    my ( $schema, $item, $quote, $basketno ) = @_;

    # create biblio record
    my $logger   = Log::Log4perl->get_logger();
    my $bib_hash = {
        'biblioitems.cn_source' => 'ddc',
        'items.cn_source'       => 'ddc',
        'items.notforloan'      => -1,
        'items.cn_sort'         => q{},
    };
    my $item_hash = {
        cn_source  => 'ddc',
        notforloan => -1,
        cn_sort    => q{},
    };
    $bib_hash->{'biblio.seriestitle'} = $item->series;

    $bib_hash->{'biblioitems.publishercode'} = $item->publisher;
    $bib_hash->{'biblioitems.publicationyear'} =
      $bib_hash->{'biblio.copyrightdate'} = $item->publication_date;

    $bib_hash->{'biblio.title'}         = $item->title;
    $bib_hash->{'biblio.author'}        = $item->author;
    $bib_hash->{'biblioitems.isbn'}     = $item->item_number_id;
    $bib_hash->{'biblioitems.itemtype'} = $item->girfield('stock_category');
    $item_hash->{booksellerid}          = $quote->vendor_id;
    $item_hash->{price} = $item_hash->{replacementprice} = $item->price;
    $item_hash->{itype} = $item->girfield('stock_category');
    $item_hash->{location} = $item->girfield('collection_code');

    my $budget = _get_budget( $schema, $item->girfield('fund_allocation') );

    if ( !$budget ) {
        carp 'Skipping line with no budget info';
        $logger->trace('line skipped for invalid budget');
        return;
    }

    my $note = {};

    my $shelfmark =
      $item->girfield('shelfmark') || $item->girfield('classification') || q{};
    $item_hash->{itemcallnumber} = $shelfmark;
    my $branch = $item->girfield('branch');
    $item_hash->{holdingbranch} = $item_hash->{homebranch} = $branch;
    for my $key ( keys %{$bib_hash} ) {
        if ( !defined $bib_hash->{$key} ) {
            delete $bib_hash->{$key};
        }
    }
    my $bib_record = TransformKohaToMarc($bib_hash);

    $logger->trace( 'Checking db for matches with ', $item->item_number_id() );
    my $bib = _check_for_existing_bib( $item->item_number_id() );
    if ( !defined $bib ) {
        $bib = {};
        ( $bib->{biblionumber}, $bib->{biblioitemnumber} ) =
          AddBiblio( $bib_record, q{} );
        $logger->trace("New biblio added $bib->{biblionumber}");
    }
    else {
        $logger->trace("Match found: $bib->{biblionumber}");
    }

    my $order_note = $item->{free_text};
    $order_note ||= q{};
    if ( !$basketno ) {
        $logger->error('Skipping order creation no basketno');
        return;
    }

    # database definitions should set some of these defaults but dont
    my $order_hash = {
        biblionumber     => $bib->{biblionumber},
        entrydate        => DateTime->now( time_zone => 'local' )->ymd(),
        quantity         => $item->quantity,
        basketno         => $basketno,
        listprice        => $item->price,
        quantityreceived => 0,

        #        notes             => $order_note, becane internalnote in 3.15
        order_internalnote => $order_note,
        rrp                => $item->price,
        ecost => _discounted_price( $quote->vendor->discount, $item->price ),
        budget_id         => $budget->budget_id,
        uncertainprice    => 0,
        sort1             => q{},
        sort2             => q{},
        supplierreference => $item->reference,
    };
    if ( $item->girfield('servicing_instruction') ) {

        # not in 3.14 !!!
        $order_hash->{order_vendornote} =
          $item->girfield('servicing_instruction');
    }
    if ( $item->internal_notes() ) {
        if ( $order_hash->{order_internalnote} ) {    # more than ''
            $order_hash->{order_internalnote} .= q{ };
        }

        $order_hash->{order_internalnote} .= $item->internal_notes;
    }


    my $new_order = $schema->resultset('Aqorder')->create($order_hash);
    my $o         = $new_order->ordernumber();
    $logger->trace("Order created :$o");

    # should be done by database settings
    $new_order->parent_ordernumber( $new_order->ordernumber() );
    $new_order->update();

    if ( C4::Context->preference('AcqCreateItem') eq 'ordering' ) {
        my $itemnumber;
        ( $bib->{biblionumber}, $bib->{biblioitemnumber}, $itemnumber ) =
          AddItem( $item_hash, $bib->{biblionumber} );
        $logger->trace("Added item:$itemnumber");
        $schema->resultset('AqordersItem')->create(
            {
                ordernumber => $new_order->ordernumber,
                itemnumber  => $itemnumber,
            }
        );

        if ( $item->quantity > 1 ) {
            my $occurence = 1;
            while ( $occurence < $item->quantity ) {
                my $new_item = {
                    notforloan       => -1,
                    cn_sort          => q{},
                    cn_source        => 'ddc',
                    price            => $item->price,
                    replacementprice => $item->price,
                    itype => $item->girfield( 'stock_category', $occurence ),
                    location =>
                      $item->girfield( 'collection_code', $occurence ),
                    itemcallnumber => $item->girfield( 'shelfmark', $occurence )
                      || $item->girfield( 'classification', $occurence ),
                    holdingbranch => $item->girfield( 'branch', $occurence ),
                    homebranch    => $item->girfield( 'branch', $occurence ),
                };
                ( undef, undef, $itemnumber ) =
                  AddItem( $new_item, $bib->{biblionumber} );
                $logger->trace("New item $itemnumber added");
                $schema->resultset('AqordersItem')->create(
                    {
                        ordernumber => $new_order->ordernumber,
                        itemnumber  => $itemnumber,
                    }
                );
                ++$occurence;
            }
        }

    }
    return 1;
}

sub get_edifact_ean {

    my $dbh = C4::Context->dbh;

    my $eans = $dbh->selectcol_arrayref('select ean from edifact_ean');

    return $eans->[0];
}

# We should not need to have a routine to do this here
sub _discounted_price {
    my ( $discount, $price ) = @_;
    return $price - ( ( $discount * $price ) / 100 );
}

sub _check_for_existing_bib {
    my $isbn = shift;

    my $search_isbn = $isbn;
    $search_isbn =~ s/^\s*/%/xms;
    $search_isbn =~ s/\s*$/%/xms;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
'select biblionumber, biblioitemnumber from biblioitems where isbn like ?',
    );
    my $tuple_arr =
      $dbh->selectall_arrayref( $sth, { Slice => {} }, $search_isbn );
    if ( @{$tuple_arr} ) {
        return $tuple_arr->[0];
    }
    else {
        undef $search_isbn;
        $isbn =~ s/\-//xmsg;
        if ( $isbn =~ m/(\d{13})/xms ) {
            my $b_isbn = Business::ISBN->new($1);
            if ( $b_isbn && $b_isbn->is_valid ) {
                $search_isbn = $b_isbn->as_isbn10->as_string( [] );
            }

        }
        elsif ( $isbn =~ m/(\d{9}[xX]|\d{10})/xms ) {
            my $b_isbn = Business::ISBN->new($1);
            if ( $b_isbn && $b_isbn->is_valid ) {
                $search_isbn = $b_isbn->as_isbn13->as_string( [] );
            }

        }
        if ($search_isbn) {
            $search_isbn = "%$search_isbn%";
            $tuple_arr =
              $dbh->selectall_arrayref( $sth, { Slice => {} }, $search_isbn );
            if ( @{$tuple_arr} ) {
                return $tuple_arr->[0];
            }
        }
    }
    return;
}

# returns a budget obj or undef
# fact we need this shows what a mess Acq API is
sub _get_budget {
    my ( $schema, $budget_code ) = @_;

    # db does not ensure budget code is unque
    return $schema->resultset('Aqbudget')->single(
        {
            budget_code => $budget_code,
        }
    );
}

1;
__END__

=head1 NAME
   Koha::EDI

=head1 SYNOPSIS

   Module exporting subroutines used in EDI processing for Koha

=head1 DESCRIPTION

   Subroutines called by batch processing to handle Edifact
   messages of various types and related utilities

=head1 BUGS

   These routines should really be methods of some object.
   get_edifact_ean is a stopgap which should be replaced

=head1 SUBROUTINES

=head2 process_quote

    process_quote(quote_message);

   passed a message object for a quote, parses it creating an order basket
   and orderlines in the database
   updates the message's status to received in the database and adds the
   link to basket

=head2 process_invoice

    process_invoice(invoice_message)

    passed a message object for an invoice, add the contained invoices
    and update the orderlines referred to in the invoice
    As an Edifact invoice is in effect a despatch note this receipts the
    appropriate quantities in the orders


=head2 create_edi_order

    create_edi_order( { parameter_hashref } )

    parameters must include basketno and ean

    branchcode can optionally be passed

    returns 1 on success undef otherwise

    if the parameter noingest is set the formatted order is returned
    and not saved in the database. This functionality is intended for debugging only

=head2 get_edifact_ean


=head2 quote_item

     quote_item(lineitem, quote_message);

      Called by process_quote to handle an individual lineitem
     Generate the biblios and items if required and orderline linking to them

=head1 AUTHOR

   Colin Campbell <colin.campbell@ptfs-europe.com>


=head1 COPYRIGHT

   Copyright 2014, PTFS-Europe Ltd
   This program is free software, You may redistribute it under
   under the terms of the GNU General Public License


=cut
