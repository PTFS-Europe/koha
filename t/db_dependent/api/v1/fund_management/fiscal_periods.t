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

use Koha::Acquisition::FundManagement::FiscalPeriods;
use Koha::Database;

# This test file contains commented out sections that other tests do not.
# These are examples for what will be used when the API definitions and permissions have been defined

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

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
    # No fiscal periods, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(200)->json_is( [] );

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(200)
        ->json_is( [ $fiscal_period->to_api ] );

    my $another_fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }

        }
    );

    # Two fiscal_periods created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(200)
        ->json_is( [ $fiscal_period->to_api, $another_fiscal_period->to_api, ] );

    # Attempt to search by code like 'ko'
    $fiscal_period->delete;
    $another_fiscal_period->delete;
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fiscal_periods?q=[{"me.code":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( [] );

    my $fiscal_period_search = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => {
                code                 => 'koha',
                lib_group_visibility => "|" . $lib_group->id . "|"
            }
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fiscal_periods?q=[{"me.code":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( [ $fiscal_period_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods?blah=blah")->status_is(400)
        ->json_is( [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods")->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

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
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    # This fiscal_period exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/" . $fiscal_period->fiscal_period_id )
        ->status_is(200)->json_is( $fiscal_period->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/" . $fiscal_period->fiscal_period_id )
        ->status_is(403);

    # Attempt to get non-existent fiscal_period
    my $non_existent_fiscal_period =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FiscalPeriods' } );
    my $non_existent_id = $non_existent_fiscal_period->fiscal_period_id;
    $non_existent_fiscal_period->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Fiscal period not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 20;

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

    my $fiscal_period = {
        description          => "test",
        code                 => "1",
        start_date           => "2024-01-01",
        end_date             => "2025-01-01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|"
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )
        ->status_is(403);

    #Authorized attempt to write invalid data
    my $fiscal_period_with_invalid_field = {
        description          => "test",
        code                 => "1",
        start_date           => "2024-01-01",
        end_date             => "2025-01-01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        blah                 => 'blah'
    };

    $t->post_ok(
        "//$userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period_with_invalid_field )
        ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
        );

    # Authorized attempt to write
    my $fiscal_period_id =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )
        ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/acquisitions/fiscal_periods/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/name' => $fiscal_period->{name} )->json_is( '/description' => $fiscal_period->{description} )
        ->json_is( '/code'                 => $fiscal_period->{code} )->json_is( '/status' => $fiscal_period->{status} )
        ->json_is( '/owner_id'             => $fiscal_period->{owner_id} )
        ->json_is( '/lib_group_visibility' => $fiscal_period->{lib_group_visibility} )
        ->tx->res->json->{fiscal_period_id};

    # Authorized attempt to create with null id
    $fiscal_period->{fiscal_period_id} = undef;
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )->status_is(400)
        ->json_has('/errors');

    # Authorized attempt to create with existing id
    $fiscal_period->{fiscal_period_id} = $fiscal_period_id;
    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods" => json => $fiscal_period )->status_is(400)
        ->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/fiscal_period_id"
            }
        ]
        );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

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

    my $fiscal_period_id =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FiscalPeriods' } )->fiscal_period_id;

    # Unauthorized attempt to update
    $t->put_ok( "//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json =>
            { name => 'New unauthorized name change' } )->status_is(403);

    # Full object update on PUT
    my $fiscal_period_with_updated_field = {
        description          => "update this",
        code                 => "1",
        start_date           => "2024-01-01",
        end_date             => "2025-01-01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|"
    };

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json =>
            $fiscal_period_with_updated_field )->status_is(200)->json_is( '/description' => 'update this' );

    # Authorized attempt to write invalid data
    my $fiscal_period_with_invalid_field = {
        blah                 => 'blah',
        description          => "test",
        code                 => "1",
        start_date           => "2024-01-01",
        end_date             => "2025-01-01",
        status               => "1",
        owner_id             => "1",
        lib_group_visibility => "|" . $lib_group->id . "|"
    };

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json =>
            $fiscal_period_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
            );

    # Attempt to update non-existent fiscal_period
    my $fiscal_period_to_delete =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FiscalPeriods' } );
    my $non_existent_id = $fiscal_period_to_delete->fiscal_period_id;
    $fiscal_period_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$non_existent_id" => json =>
            $fiscal_period_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $fiscal_period_with_updated_field->{fiscal_period_id} = 2;

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id" => json =>
            $fiscal_period_with_updated_field )->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

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

    my $fiscal_period_id =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FiscalPeriods' } )->fiscal_period_id;

    # Unauthorized attempt to delete
    $t->delete_ok("//$unauth_userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")->status_is(403);

    # Delete existing fiscal_period
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")
        ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent fiscal_period
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fiscal_periods/$fiscal_period_id")->status_is(404);

    $schema->storage->txn_rollback;
};
