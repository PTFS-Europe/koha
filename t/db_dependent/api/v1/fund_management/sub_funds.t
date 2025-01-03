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

use Koha::Acquisition::FundManagement::SubFunds;
use Koha::Database;

# This test file contains commented out sections that other tests do not.
# These are examples for what will be used when the API definitions and permissions have been defined

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
    # No sub funds, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/sub_funds")->status_is(200)->json_is( [] );

    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/sub_funds")->status_is(200)->json_is( [ $sub_fund->to_api ] );

    my $another_sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }

        }
    );

    # Two sub_funds created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/sub_funds")->status_is(200)
        ->json_is( [ $sub_fund->to_api, $another_sub_fund->to_api, ] );

    # Attempt to search by title like 'ko'
    $sub_fund->delete;
    $another_sub_fund->delete;
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/sub_funds?q=[{"me.code":{"like":"%ko%"}}]~)->status_is(200)
        ->json_is( [] );

    my $sub_funds_search = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => {
                code                 => 'koha',
                lib_group_visibility => "|" . $lib_group->id . "|"
            }
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/sub_funds?q=[{"me.code":{"like":"%ko%"}}]~)->status_is(200)
        ->json_is( [ $sub_funds_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/sub_funds?blah=blah")->status_is(400)
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
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    # This sub_funds exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/sub_funds/" . $sub_fund->sub_fund_id )->status_is(200)
        ->json_is( $sub_fund->to_api );

    # Attempt to get non-existent sub_funds
    my $non_existent_sub_funds = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::SubFunds', value => { lib_group_visibility => "|" . $lib_group->id . "|" }
 } );
    my $non_existent_id        = $non_existent_sub_funds->sub_fund_id;
    $non_existent_sub_funds->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/sub_funds/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Sub fund not found' );

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

    my $parent_fund = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::Funds', value => { lib_group_visibility => "|" . $lib_group->id . "|" } } );

    my $sub_fund = {
        name                 => "test",
        description          => "test",
        code                 => "1",
        external_id          => "01",
        status               => "1",
        lib_group_visibility => "|" . $lib_group->id . "|",
        sub_fund_type        => 'test',
        ledger_id            => $parent_fund->ledger_id,
        owner_id             => '1'
    };

    # Authorized attempt to write
    my $sub_fund_id =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/sub_funds" => json => $sub_fund )
        ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/acquisitions/sub_funds/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/name' => $sub_fund->{name} )->json_is( '/description' => $sub_fund->{description} )
        ->json_is( '/code'                 => $sub_fund->{code} )->json_is( '/status' => $sub_fund->{status} )
        ->json_is( '/owner_id'             => $sub_fund->{owner_id} )
        ->json_is( '/lib_group_visibility' => $sub_fund->{lib_group_visibility} )->tx->res->json->{sub_fund_id};

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

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

    my $library   = $builder->build_object( { class => 'Koha::Libraries' } );
    my $lib_group = Koha::Library::Group->new( { title => "Test root group" } )->store();
    my $group_library =
        Koha::Library::Group->new( { parent_id => $lib_group->id, branchcode => $library->branchcode } )->store();

    my $sub_fund_id = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::SubFunds', value => { lib_group_visibility => "|" . $lib_group->id . "|" } } )->sub_fund_id;

    # Full object update on PUT
    my $parent_fund = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::Funds', value => { lib_group_visibility => "|" . $lib_group->id . "|" } } );

    my $sub_funds_with_updated_field = {
        name                 => "new name",
        description          => "test",
        code                 => "1",
        external_id          => "01",
        status               => "1",
        lib_group_visibility => "1",
        sub_fund_type        => 'test',
        ledger_id            => $parent_fund->ledger_id
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/sub_funds/$sub_fund_id" => json => $sub_funds_with_updated_field )
        ->status_is(200)->json_is( '/name' => 'new name' );

    # Attempt to update non-existent sub_funds
    my $sub_funds_to_delete = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::SubFunds', , value => { lib_group_visibility => "|" . $lib_group->id . "|" } } );
    my $non_existent_id     = $sub_funds_to_delete->sub_fund_id;
    $sub_funds_to_delete->delete;

    $t->put_ok(
        "//$userid:$password@/api/v1/acquisitions/sub_funds/$non_existent_id" => json => $sub_funds_with_updated_field )
        ->status_is(404);

    # Wrong method (POST)
    $sub_funds_with_updated_field->{sub_fund_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/acquisitions/sub_funds/sub_fund_id" => json => $sub_funds_with_updated_field )
        ->status_is(404);

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

    my $sub_fund_id = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::SubFunds', value => { lib_group_visibility => "|" . $lib_group->id . "|" }
 } )->sub_fund_id;

    # Delete existing sub_funds
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/sub_funds/$sub_fund_id")->status_is( 204, 'SWAGGER3.2.4' )
        ->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent sub_funds
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/sub_funds/$sub_fund_id")->status_is(404);

    $schema->storage->txn_rollback;
};
