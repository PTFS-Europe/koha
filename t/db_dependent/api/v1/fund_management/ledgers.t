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

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Acquisition::FundManagement::Ledgers;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 18;

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
    # No ledgers, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [] );

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)->json_is( [ $ledger->to_api ] );

    my $another_ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }

        }
    );

    # Two ledgers created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers")->status_is(200)
        ->json_is( [ $ledger->to_api, $another_ledger->to_api, ] );

    # Attempt to search by title like 'ko'
    $ledger->delete;
    $another_ledger->delete;
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/ledgers?q=[{"me.code":{"like":"%ko%"}}]~)->status_is(200)
        ->json_is( [] );

    my $ledgers_search = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                code                 => 'koha',
                lib_group_visibility => "|" . $lib_group->id . "|"
            }
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/ledgers?q=[{"me.code":{"like":"%ko%"}}]~)->status_is(200)
        ->json_is( [ $ledgers_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers?blah=blah")->status_is(400)
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
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    # This ledger exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/" . $ledger->ledger_id )->status_is(200)
        ->json_is( $ledger->to_api );

    # Attempt to get non-existent ledgers
    my $non_existent_ledgers = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );
    my $non_existent_id = $non_existent_ledgers->ledger_id;
    $non_existent_ledgers->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Ledger not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 12;

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

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { lib_group_visibility => "|" . $lib_group->id . "|", spend_limit => 100 }
        }
    );

    my $ledger = {
        fiscal_period_id     => $fiscal_period->fiscal_period_id,
        name                 => "test",
        description          => "test",
        code                 => "1",
        external_id          => "01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
        spend_limit          => 50
    };

    # Authorized attempt to write
    my $ledger_id =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger )
        ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/acquisitions/ledgers/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/name' => $ledger->{name} )->json_is( '/description' => $ledger->{description} )
        ->json_is( '/code'                 => $ledger->{code} )->json_is( '/status' => $ledger->{status} )
        ->json_is( '/owner_id'             => $ledger->{owner_id} )
        ->json_is( '/lib_group_visibility' => $ledger->{lib_group_visibility} )->tx->res->json->{ledger_id};

    # Check the spend limits aren't breached
    my $ledger2 = {
        fiscal_period_id     => $fiscal_period->fiscal_period_id,
        name                 => "test2",
        description          => "test2",
        code                 => "1",
        external_id          => "01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
        spend_limit          => 51,
    };

    my $ledger_breach =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers" => json => $ledger2 )
        ->status_is( 400, 'SWAGGER3.2.1' )
        ->json_is( '/error' =>
            "Fiscal period spend limit breached, please reduce spend limit by 1 or increase the spend limit for this fiscal period"
        );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 13;

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

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { lib_group_visibility => "|" . $lib_group->id . "|", spend_limit => 100 }
        }
    );

    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                lib_group_visibility => "|" . $lib_group->id . "|",
                fiscal_period_id     => $fiscal_period->fiscal_period_id, spend_limit => 50, over_spend_allowed => 0
            }
        }
    );
    my $ledger_id = $ledger->ledger_id;

    # Full object update on PUT
    my $ledger_with_updated_field = {
        fiscal_period_id     => $fiscal_period->fiscal_period_id,
        name                 => "new name",
        description          => "test",
        code                 => "1",
        external_id          => "01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
        spend_limit          => 50
    };

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $ledger_with_updated_field )
        ->status_is(200)->json_is( '/name' => 'new name' );

    # Attempt to update non-existent ledgers
    my $ledger_to_delete = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );
    my $non_existent_id = $ledger_to_delete->ledger_id;
    $ledger_to_delete->delete;

    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/ledgers/$non_existent_id" => json => $ledger_with_updated_field )
        ->status_is(404);

    # Wrong method (POST)
    $ledger_with_updated_field->{ledger_id} = 2;

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $ledger_with_updated_field )
        ->status_is(404);

    # Test that spend_limit can't be reduced below the total spend if over_spend_allowed is set to false
    $ledger_with_updated_field->{spend_limit} = 40;
    delete $ledger_with_updated_field->{ledger_id};

    # Mock allocations totalling a spend of 45
    my $module = Test::MockModule->new('Koha::Acquisition::FundManagement::BaseObject');
    $module->mock(
        'total_allocations',
        sub {
            return -45;
        }
    );

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $ledger_with_updated_field )
        ->status_is(400)
        ->json_is( '/error' => "Spend limit cannot be less than the ledger value when overspend is not allowed" );

    # Test that the spend_limit can't be reduced to a value below the sum of any funds attached to it
    $ledger->over_spend_allowed(1)->store;

    $ledger_with_updated_field->{spend_limit} = 40;

    my $fund_id = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Funds',
            value => {
                lib_group_visibility => "|" . $lib_group->id . "|",       spend_limit => 50,
                fiscal_period_id     => $fiscal_period->fiscal_period_id, ledger_id   => $ledger_id
            }
        }
    )->fund_id;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id" => json => $ledger_with_updated_field )
        ->status_is(400)
        ->json_is( '/error' =>
            "The ledger spend limit is less than the total of the spend limits for the funds below, please increase spend limit by 10 or decrease the spend limit for the funds"
        );

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

    my $ledger_id = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    )->ledger_id;

    # Delete existing ledgers
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is( 204, 'SWAGGER3.2.4' )
        ->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent ledgers
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/ledgers/$ledger_id")->status_is(404);

    $schema->storage->txn_rollback;
};
