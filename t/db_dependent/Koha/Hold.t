#!/usr/bin/perl

# Copyright 2020 Koha Development team
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

use Test::More tests => 4;

use Test::Exception;
use Test::MockModule;

use t::lib::TestBuilder;

use Koha::Libraries;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'store() tests' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );
    my $item   = $builder->build_sample_item;
    throws_ok {
        Koha::Hold->new(
            {
                borrowernumber => $patron->borrowernumber,
                biblionumber   => $item->biblionumber,
                priority       => 1,
                itemnumber     => $item->itemnumber,
            }
        )->store
    }
    'Koha::Exceptions::Hold::MissingPickupLocation',
      'Exception thrown because branchcode was not passed';

    my $hold = $builder->build_object( { class => 'Koha::Holds' } );
    throws_ok {
        $hold->branchcode(undef)->store;
    }
    'Koha::Exceptions::Hold::MissingPickupLocation',
      'Exception thrown if one tries to set branchcode to null';

    $schema->storage->txn_rollback;
};

subtest 'fill() tests' => sub {

    plan tests => 13;

    $schema->storage->txn_begin;

    my $fee = 15;

    my $category = $builder->build_object(
        {
            class => 'Koha::Patron::Categories',
            value => { reservefee => $fee }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { categorycode => $category->id }
        }
    );
    my $manager = $builder->build_object( { class => 'Koha::Patrons' } );

    my $title  = 'Do what you want';
    my $biblio = $builder->build_sample_biblio( { title => $title } );
    my $item   = $builder->build_sample_item( { biblionumber => $biblio->id } );
    my $hold   = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber   => $biblio->id,
                borrowernumber => $patron->id,
                itemnumber     => $item->id,
                priority       => 10,
            }
        }
    );

    t::lib::Mocks::mock_preference( 'HoldFeeMode', 'any_time_is_collected' );
    t::lib::Mocks::mock_preference( 'HoldsLog',    1 );
    t::lib::Mocks::mock_userenv(
        { patron => $manager, branchcode => $manager->branchcode } );

    my $interface = 'api';
    C4::Context->interface($interface);

    my $ret = $hold->fill;

    is( ref($ret), 'Koha::Hold', '->fill returns the object type' );
    is( $ret->id, $hold->id, '->fill returns the object' );

    is( Koha::Holds->find($hold->id), undef, 'Hold no longer current' );
    my $old_hold = Koha::Old::Holds->find( $hold->id );

    is( $old_hold->id, $hold->id, 'reserve_id retained' );
    is( $old_hold->priority, 0, 'priority set to 0' );
    is( $old_hold->found, 'F', 'found set to F' );

    subtest 'fee applied tests' => sub {

        plan tests => 9;

        my $account = $patron->account;
        is( $account->balance, $fee, 'Charge applied correctly' );

        my $debits = $account->outstanding_debits;
        is( $debits->count, 1, 'Only one fee charged' );

        my $fee_debit = $debits->next;
        is( $fee_debit->amount * 1, $fee, 'Fee amount stored correctly' );
        is( $fee_debit->description, $title,
            'Fee description stored correctly' );
        is( $fee_debit->manager_id, $manager->id,
            'Fee manager_id stored correctly' );
        is( $fee_debit->branchcode, $manager->branchcode,
            'Fee branchcode stored correctly' );
        is( $fee_debit->interface, $interface,
            'Fee interface stored correctly' );
        is( $fee_debit->debit_type_code,
            'RESERVE', 'Fee debit_type_code stored correctly' );
        is( $fee_debit->itemnumber, $item->id,
            'Fee itemnumber stored correctly' );
    };

    my $logs = Koha::ActionLogs->search(
        {
            action => 'FILL',
            module => 'HOLDS',
            object => $hold->id
        }
    );

    is( $logs->count, 1, '1 log line added' );

    # Set HoldFeeMode to something other than any_time_is_collected
    t::lib::Mocks::mock_preference( 'HoldFeeMode', 'not_always' );
    # Disable logging
    t::lib::Mocks::mock_preference( 'HoldsLog',    0 );

    $hold = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                biblionumber   => $biblio->id,
                borrowernumber => $patron->id,
                itemnumber     => $item->id,
                priority       => 10,
            }
        }
    );

    $hold->fill;

    my $account = $patron->account;
    is( $account->balance, $fee, 'No new charge applied' );

    my $debits = $account->outstanding_debits;
    is( $debits->count, 1, 'Only one fee charged, because of HoldFeeMode' );

    $logs = Koha::ActionLogs->search(
        {
            action => 'FILL',
            module => 'HOLDS',
            object => $hold->id
        }
    );

    is( $logs->count, 0, 'HoldsLog disabled, no logs added' );

    subtest 'anonymization behavior tests' => sub {

        plan tests => 5;

        # reduce the tests noise
        t::lib::Mocks::mock_preference( 'HoldsLog',    0 );
        t::lib::Mocks::mock_preference( 'HoldFeeMode', 'not_always' );
        # unset AnonymousPatron
        t::lib::Mocks::mock_preference( 'AnonymousPatron', undef );

        # 0 == keep forever
        $patron->privacy(0)->store;
        my $hold = $builder->build_object(
            {
                class => 'Koha::Holds',
                value => { borrowernumber => $patron->id, found => undef }
            }
        );
        $hold->fill();
        is( Koha::Old::Holds->find( $hold->id )->borrowernumber,
            $patron->borrowernumber, 'Patron link is kept' );

        # 1 == "default", meaning it is not protected from removal
        $patron->privacy(1)->store;
        $hold = $builder->build_object(
            {
                class => 'Koha::Holds',
                value => { borrowernumber => $patron->id, found => undef }
            }
        );
        $hold->fill();
        is( Koha::Old::Holds->find( $hold->id )->borrowernumber,
            $patron->borrowernumber, 'Patron link is kept' );

        # 2 == delete immediately
        $patron->privacy(2)->store;
        $hold = $builder->build_object(
            {
                class => 'Koha::Holds',
                value => { borrowernumber => $patron->id, found => undef }
            }
        );

        throws_ok
            { $hold->fill(); }
            'Koha::Exception',
            'AnonymousPatron not set, exception thrown';

        $hold->discard_changes; # refresh from DB

        ok( !$hold->is_found, 'Hold is not filled' );

        my $anonymous_patron = $builder->build_object({ class => 'Koha::Patrons' });
        t::lib::Mocks::mock_preference( 'AnonymousPatron', $anonymous_patron->id );

        $hold = $builder->build_object(
            {
                class => 'Koha::Holds',
                value => { borrowernumber => $patron->id, found => undef }
            }
        );
        $hold->fill();
        is(
            Koha::Old::Holds->find( $hold->id )->borrowernumber,
            $anonymous_patron->id,
            'Patron link is set to the configured anonymous patron immediately'
        );
    };

    subtest 'holds_queue update tests' => sub {

        plan tests => 1;

        my $biblio = $builder->build_sample_biblio;

        my $mock = Test::MockModule->new('Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue');
        $mock->mock( 'enqueue', sub {
            my ( $self, $args ) = @_;
            is_deeply(
                $args->{biblio_ids},
                [ $biblio->id ],
                '->fill triggers a holds queue update for the related biblio'
            );
        } );

        t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue', 1 );

        $builder->build_object(
            {
                class => 'Koha::Holds',
                value => {
                    biblionumber   => $biblio->id,
                }
            }
        )->fill;

        t::lib::Mocks::mock_preference( 'RealTimeHoldsQueue', 0 );
        # this call shouldn't add a new test
        $builder->build_object(
            {
                class => 'Koha::Holds',
                value => {
                    biblionumber   => $biblio->id,
                }
            }
        )->fill;
    };

    $schema->storage->txn_rollback;
};

subtest 'patron() tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $hold   = $builder->build_object(
        {
            class => 'Koha::Holds',
            value => {
                borrowernumber => $patron->borrowernumber
            }
        }
    );

    my $hold_patron = $hold->patron;
    is( ref($hold_patron), 'Koha::Patron', 'Right type' );
    is( $hold_patron->id, $patron->id, 'Right object' );

    $schema->storage->txn_rollback;
};

subtest 'set_pickup_location() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    my $mock_biblio = Test::MockModule->new('Koha::Biblio');
    my $mock_item   = Test::MockModule->new('Koha::Item');

    my $library_1 = $builder->build_object({ class => 'Koha::Libraries' });
    my $library_2 = $builder->build_object({ class => 'Koha::Libraries' });
    my $library_3 = $builder->build_object({ class => 'Koha::Libraries' });

    # let's control what Koha::Biblio->pickup_locations returns, for testing
    $mock_biblio->mock( 'pickup_locations', sub {
        return Koha::Libraries->search( { branchcode => [ $library_2->branchcode, $library_3->branchcode ] } );
    });
    # let's mock what Koha::Item->pickup_locations returns, for testing
    $mock_item->mock( 'pickup_locations', sub {
        return Koha::Libraries->search( { branchcode => [ $library_2->branchcode, $library_3->branchcode ] } );
    });

    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item({ biblionumber => $biblio->biblionumber });

    # Test biblio-level holds
    my $biblio_hold = $builder->build_object(
        {
            class => "Koha::Holds",
            value => {
                biblionumber => $biblio->biblionumber,
                branchcode   => $library_3->branchcode,
                itemnumber   => undef,
            }
        }
    );

    throws_ok
        { $biblio_hold->set_pickup_location({ library_id => $library_1->branchcode }); }
        'Koha::Exceptions::Hold::InvalidPickupLocation',
        'Exception thrown on invalid pickup location';

    $biblio_hold->discard_changes;
    is( $biblio_hold->branchcode, $library_3->branchcode, 'branchcode remains untouched' );

    my $ret = $biblio_hold->set_pickup_location({ library_id => $library_2->id });
    is( ref($ret), 'Koha::Hold', 'self is returned' );

    $biblio_hold->discard_changes;
    is( $biblio_hold->branchcode, $library_2->id, 'Pickup location changed correctly' );

    # Test item-level holds
    my $item_hold = $builder->build_object(
        {
            class => "Koha::Holds",
            value => {
                biblionumber => $biblio->biblionumber,
                branchcode   => $library_3->branchcode,
                itemnumber   => $item->itemnumber,
            }
        }
    );

    throws_ok
        { $item_hold->set_pickup_location({ library_id => $library_1->branchcode }); }
        'Koha::Exceptions::Hold::InvalidPickupLocation',
        'Exception thrown on invalid pickup location';

    $item_hold->discard_changes;
    is( $item_hold->branchcode, $library_3->branchcode, 'branchcode remains untouched' );

    $item_hold->set_pickup_location({ library_id => $library_1->branchcode, force => 1 });
    $item_hold->discard_changes;
    is( $item_hold->branchcode, $library_1->branchcode, 'branchcode changed because of \'force\'' );

    $ret = $item_hold->set_pickup_location({ library_id => $library_2->id });
    is( ref($ret), 'Koha::Hold', 'self is returned' );

    $item_hold->discard_changes;
    is( $item_hold->branchcode, $library_2->id, 'Pickup location changed correctly' );

    throws_ok
        { $item_hold->set_pickup_location({ library_id => undef }); }
        'Koha::Exceptions::MissingParameter',
        'Exception thrown if missing parameter';

    is( "$@", 'The library_id parameter is mandatory', 'Exception message is clear' );

    $schema->storage->txn_rollback;
};

subtest 'is_pickup_location_valid() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $mock_biblio = Test::MockModule->new('Koha::Biblio');
    my $mock_item   = Test::MockModule->new('Koha::Item');

    my $library_1 = $builder->build_object({ class => 'Koha::Libraries' });
    my $library_2 = $builder->build_object({ class => 'Koha::Libraries' });
    my $library_3 = $builder->build_object({ class => 'Koha::Libraries' });

    # let's control what Koha::Biblio->pickup_locations returns, for testing
    $mock_biblio->mock( 'pickup_locations', sub {
        return Koha::Libraries->search( { branchcode => [ $library_2->branchcode, $library_3->branchcode ] } );
    });
    # let's mock what Koha::Item->pickup_locations returns, for testing
    $mock_item->mock( 'pickup_locations', sub {
        return Koha::Libraries->search( { branchcode => [ $library_2->branchcode, $library_3->branchcode ] } );
    });

    my $biblio = $builder->build_sample_biblio;
    my $item   = $builder->build_sample_item({ biblionumber => $biblio->biblionumber });

    # Test biblio-level holds
    my $biblio_hold = $builder->build_object(
        {
            class => "Koha::Holds",
            value => {
                biblionumber => $biblio->biblionumber,
                branchcode   => $library_3->branchcode,
                itemnumber   => undef,
            }
        }
    );

    ok( !$biblio_hold->is_pickup_location_valid({ library_id => $library_1->branchcode }), 'Pickup location invalid');
    ok( $biblio_hold->is_pickup_location_valid({ library_id => $library_2->id }), 'Pickup location valid');

    # Test item-level holds
    my $item_hold = $builder->build_object(
        {
            class => "Koha::Holds",
            value => {
                biblionumber => $biblio->biblionumber,
                branchcode   => $library_3->branchcode,
                itemnumber   => $item->itemnumber,
            }
        }
    );

    ok( !$item_hold->is_pickup_location_valid({ library_id => $library_1->branchcode }), 'Pickup location invalid');
    ok( $item_hold->is_pickup_location_valid({ library_id => $library_2->id }), 'Pickup location valid' );

    subtest 'pickup_locations() returning ->empty' => sub {

        plan tests => 2;

        $schema->storage->txn_begin;

        my $library = $builder->build_object({ class => 'Koha::Libraries' });

        my $mock_item = Test::MockModule->new('Koha::Item');
        $mock_item->mock( 'pickup_locations', sub { return Koha::Libraries->new->empty; } );

        my $mock_biblio = Test::MockModule->new('Koha::Biblio');
        $mock_biblio->mock( 'pickup_locations', sub { return Koha::Libraries->new->empty; } );

        my $item   = $builder->build_sample_item();
        my $biblio = $item->biblio;

        # Test biblio-level holds
        my $biblio_hold = $builder->build_object(
            {
                class => "Koha::Holds",
                value => {
                    biblionumber => $biblio->biblionumber,
                    itemnumber   => undef,
                }
            }
        );

        ok( !$biblio_hold->is_pickup_location_valid({ library_id => $library->branchcode }), 'Pickup location invalid');

        # Test item-level holds
        my $item_hold = $builder->build_object(
            {
                class => "Koha::Holds",
                value => {
                    biblionumber => $biblio->biblionumber,
                    itemnumber   => $item->itemnumber,
                }
            }
        );

        ok( !$item_hold->is_pickup_location_valid({ library_id => $library->branchcode }), 'Pickup location invalid');

        $schema->storage->txn_rollback;
    };

    $schema->storage->txn_rollback;
};
