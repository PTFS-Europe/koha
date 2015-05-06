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
use utf8;
use Carp;
use English qw{ -no_match_vars };
use Business::ISBN;
use DateTime;
use C4::Context;
use Koha::Database;
use C4::Acquisition qw( NewBasket );
use C4::Suggestions qw( ModSuggestion );
use C4::Items qw(AddItem);
use C4::Biblio qw( AddBiblio TransformKohaToMarc GetMarcBiblio );
use Koha::Edifact::Order;
use Koha::Edifact;
use Log::Log4perl;
use Text::Unidecode;

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

    my $schema = Koha::Database->new()->schema();

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
        my $m = unidecode($order_file); # remove diacritics and non-latin chars
        if ($noingest) {    # allows scripts to produce test files
            return $m;
        }
        my $order = {
            message_type  => 'ORDERS',
            raw_msg       => $m,
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
    $invoice_message->status('processing');
    $invoice_message->update;
    my $schema = Koha::Database->new()->schema();
    my $logger = Log::Log4perl->get_logger();
    my $vendor_acct;
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
            my $new_invoice = $schema->resultset('Aqinvoice')->create(
                {
                    invoicenumber         => $invoicenumber,
                    booksellerid          => $invoice_message->vendor_id,
                    shipmentdate          => $msg_date,
                    billingdate           => $tax_date,
                    shipmentcost          => $shipmentcharge,
                    shipmentcost_budgetid => $vendor_acct->shipment_budget,
                    message_id            => $invoice_message->id,
                }
            );
            my $invoiceid = $new_invoice->invoiceid;
            $logger->trace("Added as invoiceno :$invoiceid");
            my $lines = $msg->lineitems();

            foreach my $line ( @{$lines} ) {
                my $ordernumber = $line->ordernumber;
                $logger->trace( "Receipting order:$ordernumber Qty: ",
                    $line->quantity );

                my $order = $schema->resultset('Aqorder')->find($ordernumber);

      # ModReceiveOrder does not validate that $ordernumber exists validate here
                if ($order) {

                    # check suggestions
                    my $s = $schema->resultset('Suggestion')->search(
                        {
                            biblionumber => $order->biblionumber->biblionumber,
                        }
                    )->single;
                    if ($s) {
                        ModSuggestion(
                            {
                                suggestionid => $s->suggestionid,
                                STATUS       => 'AVAILABLE',
                            }
                        );
                    }

                    my $price = _get_invoiced_price($line);

                    if ( $order->quantity > $line->quantity ) {
                        my $ordered = $order->quantity;

                        # part receipt
                        $order->orderstatus('partial');
                        $order->quantity( $ordered - $line->quantity );
                        $order->update;
                        my $received_order = $order->copy(
                            {
                                ordernumber      => undef,
                                quantity         => $line->quantity,
                                quantityreceived => $line->quantity,
                                orderstatus      => 'complete',
                                unitprice        => $price,
                                invoiceid        => $invoiceid,
                                datereceived     => $msg_date,
                            }
                        );
                        transfer_items( $schema, $line, $order,
                            $received_order );
                        receipt_items( $schema, $line,
                            $received_order->ordernumber );
                    }
                    else {    # simple receipt all copies on order
                        $order->quantityreceived( $line->quantity );
                        $order->datereceived($msg_date);
                        $order->invoiceid($invoiceid);
                        $order->unitprice($price);
                        $order->orderstatus('complete');
                        $order->update;
                        receipt_items( $schema, $line, $ordernumber );
                    }
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

sub _get_invoiced_price {
    my $line  = shift;
    my $price =  $line->price_net;
    if ( !defined $price ) {  # no net price so generate it from lineitem amount
        $price = $line->amt_lineitem;
        if ( $price and $line->quantity > 1 ) {
            $price /= $line->quantity;    # div line cost by qty
        }
    }
    return $price;
}

sub receipt_items {
    my ( $schema, $inv_line, $ordernumber ) = @_;
    my $logger   = Log::Log4perl->get_logger();
    my $quantity = $inv_line->quantity;

    # itemnumber is not a foreign key ??? makes this a bit cumbersome
    my @item_links = $schema->resultset('AqordersItem')->search(
        {
            ordernumber => $ordernumber,
        }
    );
    my %branch_map;
    foreach my $ilink (@item_links) {
        my $item = $schema->resultset('Item')->find( $ilink->itemnumber );
        if ( !$item ) {
            my $i = $ilink->itemnumber;
            $logger->warn(
                "Cannot find aqorder item for $i :Order:$ordernumber");
            next;
        }
        my $b = $item->homebranch->branchcode;
        if ( !exists $branch_map{$b} ) {
            $branch_map{$b} = [];
        }
        push @{ $branch_map{$b} }, $item;
    }
    my $gir_occurence = 0;
    while ( $gir_occurence < $quantity ) {
        my $branch = $inv_line->girfield( 'branch', $gir_occurence );
        my $item = shift @{ $branch_map{$branch} };
        if ($item) {
            my $barcode = $inv_line->girfield( 'barcode', $gir_occurence );
            if ( $barcode && !$item->barcode ) {
                my $rs = $schema->resultset('Item')->search(
                    {
                        barcode => $barcode,
                    }
                );
                if ( $rs->count > 0 ) {
                    $logger->warn("Barcode $barcode is a duplicate");
                }
                else {

                    $logger->trace("Adding barcode $barcode");
                    $item->barcode($barcode);
                }
            }

            # clear not for loan flag
            # if ( $item->notforloan == -1 ) {
            #     $item->notforloan(0);
            # }
            $item->update;
        }
        else {
            $logger->warn("Unmatched item at branch:$branch");
        }
        ++$gir_occurence;
    }
    return;

}

sub transfer_items {
    my ( $schema, $inv_line, $order_from, $order_to ) = @_;

    # Transfer x items from the orig order to a completed partial order
    my $quantity = $inv_line->quantity;
    my $gocc     = 0;
    my %mapped_by_branch;
    while ( $gocc < $quantity ) {
        my $branch = $inv_line->girfield( 'branch', $gocc );
        if ( !exists $mapped_by_branch{$branch} ) {
            $mapped_by_branch{$branch} = 1;
        }
        else {
            $mapped_by_branch{$branch}++;
        }
        ++$gocc;
    }
    my $logger = Log::Log4perl->get_logger();
    my $o1     = $order_from->ordernumber;
    my $o2     = $order_to->ordernumber;
    $logger->warn("transferring $quantity copies from order $o1 to order $o2");

    my @item_links = $schema->resultset('AqordersItem')->search(
        {
            ordernumber => $order_from->ordernumber,
        }
    );
    foreach my $ilink (@item_links) {
        my $ino      = $ilink->itemnumber;
        my $item     = $schema->resultset('Item')->find( $ilink->itemnumber );
        my $i_branch = $item->homebranch;
        if ( exists $mapped_by_branch{$i_branch}
            && $mapped_by_branch{$i_branch} > 0 )
        {
            $ilink->ordernumber( $order_to->ordernumber );
            $ilink->update;
            --$quantity;
            --$mapped_by_branch{$i_branch};
            $logger->warn("Transferred item $item");
        }
        else {
            $logger->warn("Skipped item $item");
        }
        if ( $quantity < 1 ) {
            last;
        }
    }

    return;
}

# called on messages with status 'new'
sub process_quote {
    my $quote = shift;

    $quote->status('processing');
    $quote->update;

    my $edi = Koha::Edifact->new( { transmission => $quote->raw_msg, } );

    my $messages       = $edi->message_array();
    my $process_errors = 0;
    my $logger         = Log::Log4perl->get_logger();
    my $schema         = Koha::Database->new()->schema();
    my $message_count  = 0;

    if ( @{$messages} && $quote->vendor_id ) {
        foreach my $msg ( @{$messages} ) {
            ++$message_count;
            my $basketno =
              NewBasket( $quote->vendor_id, 0, $quote->filename, q{},
                q{} . q{} );
            if ( $message_count > 1 ) {
                my $m_filename = $quote->filename;
                $m_filename .= "_$message_count";
                $schema->resultset('EdifactMessage')->create(
                    {
                        message_type  => $quote->message_type,
                        transfer_date => $quote->transfer_date,
                        vendor_id     => $quote->vendor_id,
                        edi_acct      => $quote->edi_acct,
                        status        => 'recmsg',
                        basketno      => $basketno,
                        raw_msg       => q{},
                        filename      => $m_filename,
                    }
                );
            }
            else {
                $quote->basketno($basketno);
            }
            $logger->trace("Created basket :$basketno");
            my $items  = $msg->lineitems();
            my $refnum = $msg->message_refno;

            for my $item ( @{$items} ) {
                if ( !quote_item( $item, $quote, $basketno ) ) {
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
    my ( $item, $quote, $basketno ) = @_;

    my $schema = Koha::Database->new()->schema();

    # create biblio record
    my $logger = Log::Log4perl->get_logger();
    if ( !$basketno ) {
        $logger->error('Skipping order creation no basketno');
        return;
    }
    $logger->trace( 'Checking db for matches with ', $item->item_number_id() );
    my $bib = _check_for_existing_bib( $item->item_number_id() );
    if ( !defined $bib ) {
        $bib = {};
        my $bib_record = _create_bib_from_quote( $item, $quote );
        ( $bib->{biblionumber}, $bib->{biblioitemnumber} ) =
          AddBiblio( $bib_record, q{} );
        $logger->trace("New biblio added $bib->{biblionumber}");
    }
    else {
        $logger->trace("Match found: $bib->{biblionumber}");
    }

    # Create an orderline
    my $order_note = $item->{free_text};
    $order_note ||= q{};

    # database definitions should set some of these defaults but dont
    my $order_hash = {
        biblionumber       => $bib->{biblionumber},
        entrydate          => DateTime->now( time_zone => 'local' )->ymd(),
        basketno           => $basketno,
        listprice          => $item->price,
        quantity           => 1,
        quantityreceived   => 0,
        order_internalnote => $order_note,
        rrp                => $item->price,
        ecost => _discounted_price( $quote->vendor->discount, $item->price ),
        uncertainprice    => 0,
        sort1             => q{},
        sort2             => q{},
        supplierreference => $item->reference,
    };

    if ( $item->girfield('servicing_instruction') ) {
        $order_hash->{order_vendornote} =
          $item->girfield('servicing_instruction');
    }

    if ( $item->internal_notes() ) {
        if ( $order_hash->{order_internalnote} ) {    # more than ''
            $order_hash->{order_internalnote} .= q{ };
        }
        $order_hash->{order_internalnote} .= $item->internal_notes;
    }

    my $budget = _get_budget( $schema, $item->girfield('fund_allocation') );

    my $skip = '0';
    if ( !$budget ) {
        if ( $item->quantity > 1 ) {
            carp 'Skipping line with no budget info';
            $logger->trace('girfield skipped for invalid budget');
            $skip++;
        }
        else {
            carp 'Skipping line with no budget info';
            $logger->trace('orderline skipped for invalid budget');
            return;
        }
    }

    my %ordernumber;
    my %budgets;
    my $item_hash;

    if ( !$skip ) {
        $order_hash->{budget_id} = $budget->budget_id;
        my $first_order = $schema->resultset('Aqorder')->create($order_hash);
        my $o           = $first_order->ordernumber();
        $logger->trace("Order created :$o");

        # should be done by database settings
        $first_order->parent_ordernumber( $first_order->ordernumber() );
        $first_order->update();

        # add to $budgets to prevent duplicate orderlines
        $budgets{ $budget->budget_id } = '1';

        # record ordernumber against budget
        $ordernumber{ $budget->budget_id } = $o;

        if ( C4::Context->preference('AcqCreateItem') eq 'ordering' ) {
            $item_hash = _create_item_from_quote( $item, $quote );

            my $itemnumber;
            ( $bib->{biblionumber}, $bib->{biblioitemnumber}, $itemnumber ) =
              AddItem( $item_hash, $bib->{biblionumber} );
            $logger->trace("Added item:$itemnumber");
            $schema->resultset('AqordersItem')->create(
                {
                    ordernumber => $first_order->ordernumber,
                    itemnumber  => $itemnumber,
                }
            );
        }
    }

    if ( $item->quantity > 1 ) {
        my $occurence = 1;
        while ( $occurence < $item->quantity ) {

            # check budget code
            $budget = _get_budget( $schema,
                $item->girfield( 'fund_allocation', $occurence ) );

            if ( !$budget ) {
                my $bad_budget =
                  $item->girfield( 'fund_allocation', $occurence );
                carp 'Skipping line with no budget info';
                $logger->trace(
                    "girfield skipped for invalid budget:$bad_budget");
                ++$occurence;    ## lets look at the next one not this one again
                next;
            }

            # add orderline for NEW budget in $budgets
            if ( !exists $budgets{ $budget->budget_id } ) {

                # $order_hash->{quantity} = 1; by default above
                # we should handle both 1:1 GIR & 1:n GIR (with LQT values) here

                $order_hash->{budget_id} = $budget->budget_id;

                my $new_order =
                  $schema->resultset('Aqorder')->create($order_hash);
                my $o = $new_order->ordernumber();
                $logger->trace("Order created :$o");

                # should be done by database settings
                $new_order->parent_ordernumber( $new_order->ordernumber() );
                $new_order->update();

                # add to $budgets to prevent duplicate orderlines
                $budgets{ $budget->budget_id } = '1';

                # record ordernumber against budget
                $ordernumber{ $budget->budget_id } = $o;

                if ( C4::Context->preference('AcqCreateItem') eq 'ordering' ) {
                    if ( !defined $item_hash ) {
                        $item_hash = _create_item_from_quote( $item, $quote );
                    }
                    my $new_item = {
                        notforloan       => -1,
                        cn_sort          => q{},
                        cn_source        => 'ddc',
                        price            => $item->price,
                        replacementprice => $item->price,
                        itype =>
                          $item->girfield( 'stock_category', $occurence ),
                        location =>
                          $item->girfield( 'collection_code', $occurence ),
                        itemcallnumber =>
                          $item->girfield( 'shelfmark', $occurence )
                          || $item->girfield( 'classification', $occurence )
                          || $item_hash->{itemcallnumber},
                        holdingbranch =>
                          $item->girfield( 'branch', $occurence ),
                        homebranch => $item->girfield( 'branch', $occurence ),
                    };
                    my $itemnumber;
                    ( undef, undef, $itemnumber ) =
                      AddItem( $new_item, $bib->{biblionumber} );
                    $logger->trace("New item $itemnumber added");
                    $schema->resultset('AqordersItem')->create(
                        {
                            ordernumber => $new_order->ordernumber,
                            itemnumber  => $itemnumber,
                        }
                    );
                }

                ++$occurence;
            }

            # increment quantity in orderline for EXISTING budget in $budgets
            else {
                my $row = $schema->resultset('Aqorder')->find(
                    {
                        ordernumber => $ordernumber{ $budget->budget_id }
                    }
                );
                if ($row) {
                    my $qty = $row->quantity;
                    $qty++;
                    $row->update(
                        {
                            quantity => $qty,
                        }
                    );
                }

                if ( C4::Context->preference('AcqCreateItem') eq 'ordering' ) {
                    my $new_item = {
                        notforloan       => -1,
                        cn_sort          => q{},
                        cn_source        => 'ddc',
                        price            => $item->price,
                        replacementprice => $item->price,
                        itype =>
                          $item->girfield( 'stock_category', $occurence ),
                        location =>
                          $item->girfield( 'collection_code', $occurence ),
                        itemcallnumber =>
                          $item->girfield( 'shelfmark', $occurence )
                          || $item->girfield( 'classification', $occurence )
                          || $item_hash->{itemcallnumber},
                        holdingbranch =>
                          $item->girfield( 'branch', $occurence ),
                        homebranch => $item->girfield( 'branch', $occurence ),
                    };
                    my $itemnumber;
                    ( undef, undef, $itemnumber ) =
                      AddItem( $new_item, $bib->{biblionumber} );
                    $logger->trace("New item $itemnumber added");
                    $schema->resultset('AqordersItem')->create(
                        {
                            ordernumber => $ordernumber{ $budget->budget_id },
                            itemnumber  => $itemnumber,
                        }
                    );
                }

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
    elsif ( length($isbn) == 13 && $isbn !~ /^97[89]/ ) {
        my $tarr = $dbh->selectall_arrayref(
'select biblionumber, biblioitemnumber from biblioitems where ean = ?',
            { Slice => {} },
            $isbn
        );
        if ( @{$tarr} ) {
            return $tarr->[0];
        }
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

# try to get title level classification from incoming quote
sub title_level_class {
    my ($item)         = @_;
    my $class          = q{};
    my $default_scheme = C4::Context->preference('DefaultClassificationSource');
    if ( $default_scheme eq 'ddc' ) {
        $class = $item->dewey_class();
    }
    elsif ( $default_scheme eq 'lcc' ) {
        $class = $item->lc_class();
    }
    if ( !$class ) {
        $class =
             $item->girfield('shelfmark')
          || $item->girfield('classification')
          || q{};
    }
    return $class;
}

sub _create_bib_from_quote {
    my ( $item, $quote ) = @_;
    my $itemid = $item->item_number_id;
    my $defalt_classification_source =
      C4::Context->preference('DefaultClassificationSource');
    my $bib_hash = {
        'biblioitems.cn_source' => $defalt_classification_source,
        'items.cn_source'       => $defalt_classification_source,
        'items.notforloan'      => -1,
        'items.cn_sort'         => q{},
    };
    $bib_hash->{'biblio.seriestitle'} = $item->series;

    $bib_hash->{'biblioitems.publishercode'} = $item->publisher;
    $bib_hash->{'biblioitems.publicationyear'} =
      $bib_hash->{'biblio.copyrightdate'} = $item->publication_date;

    $bib_hash->{'biblio.title'}         = $item->title;
    $bib_hash->{'biblio.author'}        = $item->author;
    $bib_hash->{'biblioitems.isbn'}     = $item->item_number_id;
    $bib_hash->{'biblioitems.itemtype'} = $item->girfield('stock_category');

    # If we have a 13 digit id we are assuming its an ean
    # (it may also be an isbn or issn)
    if ( $itemid =~ /^\d{13}$/ ) {
        $bib_hash->{'biblioitems.ean'} = $itemid;
        if ( $itemid =~ /^977/ ) {
            $bib_hash->{'biblioitems.issn'} = $itemid;
        }
    }
    for my $key ( keys %{$bib_hash} ) {
        if ( !defined $bib_hash->{$key} ) {
            delete $bib_hash->{$key};
        }
    }
    return TransformKohaToMarc($bib_hash);

}

sub _create_item_from_quote {
    my ( $item, $quote ) = @_;
    my $defalt_classification_source =
      C4::Context->preference('DefaultClassificationSource');
    my $item_hash = {
        cn_source  => $defalt_classification_source,
        notforloan => -1,
        cn_dort    => q{},
    };
    $item_hash->{booksellerid} = $quote->vendor_id;
    $item_hash->{price}        = $item_hash->{replacementprice} = $item->price;
    $item_hash->{itype}        = $item->girfield('stock_category');
    $item_hash->{location}     = $item->girfield('collection_code');

    my $note = {};

    $item_hash->{itemcallnumber} = title_level_class($item);

    my $branch = $item->girfield('branch');
    $item_hash->{holdingbranch} = $item_hash->{homebranch} = $branch;
    return $item_hash;
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
e
    my $database       = Koha::Database->new();

=head2 get_edifact_ean

    $ean = get_edifact_ean();

    routine to return the ean.

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
