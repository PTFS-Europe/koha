#!/usr/bin/perl

# Copyright 2017 Koha Development team
#
# This file is part of Koha
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

use Test::More tests => 6;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'basket() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $basket = $builder->build_object(
        {
            class => 'Koha::Acquisition::Baskets'
        }
    );
    my $order = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => { basketno => $basket->basketno }
        }
    );

    my $retrieved_basket = $order->basket;
    is( ref($retrieved_basket), 'Koha::Acquisition::Basket',
        'Type is correct for ->basket' );
    is_deeply( $retrieved_basket->unblessed,
        $basket->unblessed, "Correct basket found and updated" );

    $schema->storage->txn_rollback;
};

subtest 'store' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;
    my $o = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders'
        }
    );

    subtest 'entrydate' => sub {
        plan tests => 2;

        my $order;

        t::lib::Mocks::mock_preference( 'TimeFormat', '12hr' );
        $order = Koha::Acquisition::Order->new(
            {
                basketno     => $o->basketno,
                biblionumber => $o->biblionumber,
                budget_id    => $o->budget_id,
                quantity     => 1,
            }
        )->store;
        $order->discard_changes;
        like( $order->entrydate, qr|^\d{4}-\d{2}-\d{2}$| );

        t::lib::Mocks::mock_preference( 'TimeFormat', '24hr' );
        $order = Koha::Acquisition::Order->new(
            {
                basketno     => $o->basketno,
                biblionumber => $o->biblionumber,
                budget_id    => $o->budget_id,
                quantity     => 1,
            }
        )->store;
        $order->discard_changes;
        like( $order->entrydate, qr|^\d{4}-\d{2}-\d{2}$| );
    };
    $schema->storage->txn_rollback;
};

subtest 'fund' => sub {
    plan tests => 1;

    $schema->storage->txn_begin;
    my $o = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
        }
    );

    my $order = Koha::Acquisition::Orders->find( $o->ordernumber );
    is( ref( $order->fund ),
        'Koha::Acquisition::Fund',
        '->fund should return a Koha::Acquisition::Fund object' );
    $schema->storage->txn_rollback;
};

subtest 'invoice' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    my $o = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => { cancellationreason => 'XXXXXXXX', invoiceid => undef }, # not received yet
        }
    );

    my $order = Koha::Acquisition::Orders->find( $o->ordernumber );
    is( $order->invoice, undef,
        '->invoice should return undef if no invoice defined yet');

    my $invoice = $builder->build_object(
        {
            class => 'Koha::Acquisition::Invoices',
        },
    );

    $o->invoiceid( $invoice->invoiceid )->store;
    $order = Koha::Acquisition::Orders->find( $o->ordernumber );
    is( ref( $order->invoice ), 'Koha::Acquisition::Invoice',
        '->invoice should return a Koha::Acquisition::Invoice object if an invoice is defined');

    $schema->storage->txn_rollback;
};

subtest 'subscription' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;
    my $o = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value => { subscriptionid => undef }, # not linked to a subscription
        }
    );

    my $order = Koha::Acquisition::Orders->find( $o->ordernumber );
    is( $order->subscription, undef,
        '->subscription should return undef if not created from a subscription');

    $o = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            # Will be linked to a subscription by TestBuilder
        }
    );

    $order = Koha::Acquisition::Orders->find( $o->ordernumber );
    is( ref( $order->subscription ), 'Koha::Subscription',
        '->subscription should return a Koha::Subscription object if created from a subscription');

    $schema->storage->txn_rollback;
};

subtest 'duplicate_to | add_item' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $item = $builder->build_sample_item;
    my $order_no_sub = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value =>
              {
                  biblionumber => $item->biblionumber,
                  subscriptionid => undef, # not linked to a subscription
              }
        }
    );
    $order_no_sub->basket->create_items(undef)->store; # use syspref
    $order_no_sub->add_item( $item->itemnumber );

    $item = $builder->build_sample_item;
    my $order_from_sub = $builder->build_object(
        {
            class => 'Koha::Acquisition::Orders',
            value =>
              {
                  biblionumber => $item->biblionumber,
                  # Will be linked to a subscription by TestBuilder
              }
        }
    );
    $order_from_sub->basket->create_items(undef)->store; # use syspref
    $order_from_sub->add_item( $item->itemnumber );

    my $basket_to = $builder->build_object(
         { class => 'Koha::Acquisition::Baskets' });

    subtest 'Create item on receiving' => sub {
        plan tests => 2;

        t::lib::Mocks::mock_preference('AcqCreateItem', 'receiving');

        my $duplicated_order = $order_no_sub->duplicate_to($basket_to);
        is( $duplicated_order->items->count, 0,
            'Items should not be copied if the original order did not create items on ordering'
        );

        $duplicated_order = $order_from_sub->duplicate_to($basket_to);
        is( $duplicated_order->items->count, 0,
            'Items should not be copied if the original order is created from a subscription'
        );
    };

    subtest 'Create item on ordering' => sub {
        plan tests => 2;

        t::lib::Mocks::mock_preference('AcqCreateItem', 'ordering');

        my $duplicated_order = $order_no_sub->duplicate_to($basket_to);
        is( $duplicated_order->items->count, 1,
            'Items should be copied if items are created on ordering'
        );

        $duplicated_order = $order_from_sub->duplicate_to($basket_to);
        is( $duplicated_order->items->count, 0,
            'Items should never be copied if the original order is created from a subscription'
        );
    };

    $schema->storage->txn_rollback;
};
