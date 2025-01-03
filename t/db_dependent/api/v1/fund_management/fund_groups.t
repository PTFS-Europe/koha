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

use Koha::Acquisition::FundManagement::FundGroups;
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
    # No fund groups, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_groups")->status_is(200)->json_is( [] );

    my $fund_group = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundGroups',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_groups")->status_is(200)
        ->json_is( [ $fund_group->to_api ] );

    my $another_fund_group = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundGroups',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }

        }
    );

    # Two fund_groups created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_groups")->status_is(200)
        ->json_is( [ $fund_group->to_api, $another_fund_group->to_api, ] );

    # Attempt to search by title like 'ko'
    $fund_group->delete;
    $another_fund_group->delete;
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fund_groups?q=[{"me.name":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( [] );

    my $fund_groups_search = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundGroups',
            value => {
                name                 => 'koha',
                lib_group_visibility => "|" . $lib_group->id . "|"
            }
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok(qq~//$userid:$password@/api/v1/acquisitions/fund_groups?q=[{"me.name":{"like":"%ko%"}}]~)
        ->status_is(200)->json_is( [ $fund_groups_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_groups?blah=blah")->status_is(400)
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
    my $fund_group = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundGroups',
            value => { lib_group_visibility => "|" . $lib_group->id . "|" }
        }
    );

    # This fund_group exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/acquisitions/fund_groups/" . $fund_group->fund_group_id )->status_is(200)
        ->json_is( $fund_group->to_api );

    # Attempt to get non-existent fund_groups
    my $non_existent_fund_groups =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FundGroups' } );
    my $non_existent_id = $non_existent_fund_groups->fund_group_id;
    $non_existent_fund_groups->delete;

    $t->get_ok("//$userid:$password@/api/v1/acquisitions/fund_groups/$non_existent_id")->status_is(404)
        ->json_is( '/error' => 'Fund group not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

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

    my $fund_group = {
        name                 => "test",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
    };

    # Authorized attempt to write
    my $fund_group_id =
        $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fund_groups" => json => $fund_group )
        ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/acquisitions/fund_groups/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/name' => $fund_group->{name} )->json_is( '/currency' => $fund_group->{currency} )
        ->json_is( '/lib_group_visibility' => $fund_group->{lib_group_visibility} )->tx->res->json->{fund_group_id};

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

    my $fund_group_id =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FundGroups' } )->fund_group_id;

    # Full object update on PUT
    my $fund_groups_with_updated_field = {
        name                 => "new name",
        lib_group_visibility => "|" . $lib_group->id . "|",
        currency             => "GBP",
    };

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/fund_groups/$fund_group_id" => json =>
            $fund_groups_with_updated_field )->status_is(200)->json_is( '/name' => 'new name' );

    # Attempt to update non-existent fund_groups
    my $fund_groups_to_delete = $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FundGroups' } );
    my $non_existent_id       = $fund_groups_to_delete->fund_group_id;
    $fund_groups_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/acquisitions/fund_groups/$non_existent_id" => json =>
            $fund_groups_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $fund_groups_with_updated_field->{fund_group_id} = 2;

    $t->post_ok( "//$userid:$password@/api/v1/acquisitions/fund_groups/$fund_group_id" => json =>
            $fund_groups_with_updated_field )->status_is(404);

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

    my $fund_group_id =
        $builder->build_object( { class => 'Koha::Acquisition::FundManagement::FundGroups' } )->fund_group_id;

    # Delete existing fund_groups
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fund_groups/$fund_group_id")
        ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent fund_groups
    $t->delete_ok("//$userid:$password@/api/v1/acquisitions/fund_groups/$fund_group_id")->status_is(404);

    $schema->storage->txn_rollback;
};
