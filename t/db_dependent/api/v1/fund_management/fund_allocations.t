#!/usr/bin/env perl

# Copyright 2024 PTFS Europe

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

use Test::More tests => 4;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::FundManagement::FundAllocations;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 23;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $lib_group = Koha::Library::Group->new( { title => "Test root group" } )->store();
    my $group_library =
        Koha::Library::Group->new( { parent_id => $lib_group->id, branchcode => $library->branchcode } )->store();

    my $module = Test::MockModule->new('C4::Context');
    $module->mock(
        'mybranch',
        sub {
            return $library->branchcode;
        }
    );

    ## Authorized user tests
    # No fund allocations, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations")->status_is(200)->json_is( [] );

    my $fund_allocation = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    my $module2 = Test::MockModule->new('Koha::Acquisition::FundManagement::FundAllocations');
    $module2->mock(
        'add_totals_to_fund_allocations',
        sub {
            my @allocations = ();
            push @allocations, $fund_allocation->unblessed;
            return \@allocations;
        }
    );
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations")->status_is(200)
        ->json_is( '/0/currency'  => $fund_allocation->currency )
        ->json_is( '/0/reference' => $fund_allocation->reference );

    my $another_fa = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    $module2->mock(
        'add_totals_to_fund_allocations',
        sub {
            my @allocations = ();
            push @allocations, $fund_allocation->unblessed;
            push @allocations, $another_fa->unblessed;
            return \@allocations;
        }
    );

    # Two fund_allocations created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations")->status_is(200)
        ->json_is( '/0/currency'  => $fund_allocation->currency )
        ->json_is( '/0/reference' => $fund_allocation->reference )->json_is( '/1/currency' => $another_fa->currency )
        ->json_is( '/1/reference' => $another_fa->reference );

    # Attempt to search by title like 'ko'
    $fund_allocation->delete;
    $another_fa->delete;
    $module2->mock(
        'add_totals_to_fund_allocations',
        sub {
            my @allocations = ();
            return \@allocations;
        }
    );
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fund_allocations?q=[{"me.reference":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( [] );

    my $fund_allocations_search = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => {
                reference            => 'koha',
                lib_group_visibility => "|" . $lib_group->id . "|"
            }
        }
    );
    $module2->mock(
        'add_totals_to_fund_allocations',
        sub {
            my @allocations = ();
            push @allocations, $fund_allocations_search->unblessed;
            return \@allocations;
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fund_allocations?q=[{"me.reference":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( '/0/currency' => $fund_allocations_search->currency )
        ->json_is( '/0/reference' => $fund_allocations_search->reference );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations?blah=blah")->status_is(400)
        ->json_is( [ { path => '/query/blah', message => 'Malformed query string' } ] );

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $lib_group = Koha::Library::Group->new( { title => "Test root group" } )->store();
    my $group_library =
        Koha::Library::Group->new( { parent_id => $lib_group->id, branchcode => $library->branchcode } )->store();

    my $module = Test::MockModule->new('C4::Context');
    $module->mock(
        'mybranch',
        sub {
            return $library->branchcode;
        }
    );
    my $fund_allocation = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    # This fund_allocation exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/fund_allocations/" . $fund_allocation->fund_allocation_id )
        ->status_is(200)->json_is( $fund_allocation->to_api );

    # Attempt to get non-existent fund_allocations
    my $non_existent_fund_allocations = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );
    my $non_existent_id = $non_existent_fund_allocations->fund_allocation_id;
    $non_existent_fund_allocations->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Fund allocation not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 9;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $lib_group = Koha::Library::Group->new( { title => "Test root group" } )->store();
    my $group_library =
        Koha::Library::Group->new( { parent_id => $lib_group->id, branchcode => $library->branchcode } )->store();

    my $module = Test::MockModule->new('C4::Context');
    $module->mock(
        'mybranch',
        sub {
            return $library->branchcode;
        }
    );

    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Funds',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    my $fund_allocation = {
        allocation_amount    => "10",
        reference            => "test",
        note                 => "test",
        is_transfer          => "0",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
        fund_id              => $fund->fund_id,
        sub_fund_id          => undef,
        ledger_id            => $fund->ledger_id,
        fiscal_period_id     => $fund->fiscal_period_id
    };

    # Authorized attempt to write
    my $fund_allocation_id =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fund_allocations" => json => $fund_allocation )
        ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/acquisitions/fund_allocations/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/allocation_amount' => $fund_allocation->{allocation_amount} )
        ->json_is( '/reference'   => $fund_allocation->{reference} )->json_is( '/note' => $fund_allocation->{note} )
        ->json_is( '/is_transfer' => $fund_allocation->{is_transfer} )
        ->json_is( '/owner_id'    => $fund_allocation->{owner_id} )
        ->json_is( '/lib_group_visibility' => $fund_allocation->{lib_group_visibility} )
        ->tx->res->json->{fund_allocation_id};

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**11 }
        }
    );
    my $password = 'thePassword123';
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $librarian->userid;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $unauth_userid = $patron->userid;

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $lib_group = Koha::Library::Group->new( { title => "Test root group" } )->store();
    my $group_library =
        Koha::Library::Group->new( { parent_id => $lib_group->id, branchcode => $library->branchcode } )->store();

    my $fund_allocation_id = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    )->fund_allocation_id;

    # Delete existing fund_allocations
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations/$fund_allocation_id")
        ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent fund_allocations
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fund_allocations/$fund_allocation_id")->status_is(404);

    $schema->storage->txn_rollback;
};
