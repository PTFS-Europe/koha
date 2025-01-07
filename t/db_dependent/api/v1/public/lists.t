#!/usr/bin/env perl

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

use JSON qw(encode_json);

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Virtualshelves;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list_public() tests' => sub {

    plan tests => 30;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons' } );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    my $patron_1_userid = $patron_1->userid;

    $patron_2->set_password( { password => $password, skip_validation => 1 } );
    my $patron_2_userid = $patron_2->userid;

    my $list_1 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron_1->id, public => 1 }
        }
    );
    my $list_2 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron_1->id, public => 0 }
        }
    );
    my $list_3 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron_2->id, public => 1 }
        }
    );
    my $list_4 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron_2->id, public => 0 }
        }
    );

    my $q = encode_json( { list_id => { -in => [ $list_1->id, $list_2->id, $list_3->id, $list_4->id, ] } } );

    # anonymous
    $t->get_ok("/api/v1/public/lists?q=$q")->status_is( 200, "Anonymous users can only fetch public lists" )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } )
        ]
    );

    $t->get_ok("/api/v1/public/lists?q=$q&only_public=1")
        ->status_is( 200, "Anonymous users can only fetch public lists" )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } )
        ]
        );

    $t->get_ok("/api/v1/public/lists?q=$q&only_mine=1")->status_is(
        400,
        "Passing only_mine on an anonymous session generates a 400 code"
    )->json_is( '/error_code' => q{only_mine_forbidden} );

    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_mine=1")->status_is(
        200,
        "Passing only_mine with a logged in user makes it return only their lists"
    )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_2->to_api( { public => 1 } )
        ]
    );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q&only_mine=1")->status_is(
        200,
        "Passing only_mine with a logged in user makes it return only their lists"
    )->json_is(
        [
            $list_3->to_api( { public => 1 } ),
            $list_4->to_api( { public => 1 } )
        ]
    );

    # only public
    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_public=1")->status_is(
        200,
        "Passing only_public with a logged in user makes it return only public lists"
    )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } )
        ]
    );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q&only_public=1")->status_is(
        200,
        "Passing only_public with a logged in user makes it return only public lists"
    )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } )
        ]
    );

    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q")->status_is(
        200,
        "Not filtering with only_mine or only_public makes it return all accessible lists"
    )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_2->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } )
        ]
    );

    $t->get_ok("//$patron_2_userid:$password@/api/v1/public/lists?q=$q")->status_is(
        200,
        "Not filtering with only_mine or only_public makes it return all accessible lists"
    )->json_is(
        [
            $list_1->to_api( { public => 1 } ),
            $list_3->to_api( { public => 1 } ),
            $list_4->to_api( { public => 1 } )
        ]
    );

    # conflicting params
    $t->get_ok("//$patron_1_userid:$password@/api/v1/public/lists?q=$q&only_public=1&only_mine=1")->status_is(
        200,
        "Passing only_public with a logged in user makes it return only public lists"
    )->json_is( [ $list_1->to_api( { public => 1 } ) ] );

    $schema->storage->txn_rollback;
};

subtest 'public_get() tests' => sub {
    plan tests => 12;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron_1 = $builder->build_object( { class => 'Koha::Patrons' } );
    my $patron_2 = $builder->build_object( { class => 'Koha::Patrons' } );

    $patron_1->set_password( { password => $password, skip_validation => 1 } );
    $patron_2->set_password( { password => $password, skip_validation => 1 } );

    my $patron_1_userid = $patron_1->userid;
    my $patron_2_userid = $patron_2->userid;

    # Create test lists
    my $public_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron_1->id,
                public                  => 1,
                allow_change_from_owner => 1
            }
        }
    );

    my $private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron_1->id,
                public                  => 0,
                allow_change_from_owner => 0
            }
        }
    );

    # Test anonymous access to public list
    $t->get_ok( "/api/v1/public/lists/" . $public_list->id )->status_is(200)->json_is( $public_list->to_api );

    # Test anonymous access to private list
    $t->get_ok( "/api/v1/public/lists/" . $private_list->id )
        ->status_is( 403, 'Anonymous user cannot access private list' );

    # Test authenticated access - owner can see their private list
    $t->get_ok( "//$patron_1_userid:$password@/api/v1/public/lists/" . $private_list->id )->status_is(200)
        ->json_is( $private_list->to_api );

    # Test non-owner access to private list
    $t->get_ok( "//$patron_2_userid:$password@/api/v1/public/lists/" . $private_list->id )
        ->status_is( 403, 'Non-owner cannot access private list' );

    # Test non-existent list
    $t->get_ok("/api/v1/public/lists/99999999")->status_is( 404, "List not found" );

    $schema->storage->txn_rollback;
};

subtest 'public_add() tests' => sub {
    plan tests => 9;    # Reduced test count since we're removing one assertion

    $schema->storage->txn_begin;

    my $password       = 'thePassword123';
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $patron_userid = $patron->userid;

    my $list_data = {
        name                     => "Test List",
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    # Test anonymous attempt
    $t->post_ok( "/api/v1/public/lists" => json => $list_data )->status_is( 401, 'Anonymous user cannot create list' );

    # Test authenticated user can create list
    $t->post_ok( "//$patron_userid:$password@/api/v1/public/lists" => json => $list_data )->status_is(201)
        ->json_has( '/list_id', 'List ID is present in response' )
        ->json_has( '/name',    'List name is present in response' )->json_is(
        '/owner_id' => $patron->id,
        'List created with logged in user as owner'
        );

    # Test attempt to specify owner_id
    my $list_with_owner = {
        name                     => "Test List",
        owner_id                 => $another_patron->id,    # Should be rejected
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->post_ok( "//$patron_userid:$password@/api/v1/public/lists" => json => $list_with_owner )->status_is(400);

    $schema->storage->txn_rollback;
};

subtest 'public_update() tests' => sub {
    plan tests => 15;

    $schema->storage->txn_begin;

    my $password       = 'thePassword123';
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    $another_patron->set_password( { password => $password, skip_validation => 1 } );

    my $patron_userid         = $patron->userid;
    my $another_patron_userid = $another_patron->userid;

    # Create a list that can be modified
    my $modifiable_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron->id,
                public                  => 1,
                allow_change_from_owner => 1
            }
        }
    );

    # Create a list that cannot be modified
    my $unmodifiable_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron->id,
                public                  => 1,
                allow_change_from_owner => 0
            }
        }
    );

    my $update_data = {
        name                     => "Updated List Name",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    # Test anonymous attempt
    $t->put_ok( "/api/v1/public/lists/" . $modifiable_list->id => json => $update_data )
        ->status_is( 401, 'Anonymous user cannot update list' );

    # Test non-owner update attempt
    $t->put_ok(
        "//$another_patron_userid:$password@/api/v1/public/lists/" . $modifiable_list->id => json => $update_data )
        ->status_is( 403, 'Non-owner cannot update list' );

    # Test owner update success
    $t->put_ok( "//$patron_userid:$password@/api/v1/public/lists/" . $modifiable_list->id => json => $update_data )
        ->status_is(200)->json_is( '/name' => 'Updated List Name', 'List name updated' )
        ->json_is( '/public' => 0, 'List privacy updated' );

    # Test update of non-existent list
    $t->put_ok( "//$patron_userid:$password@/api/v1/public/lists/99999999" => json => $update_data )
        ->status_is( 404, "List not found" );

    # Test update of unmodifiable list
    $t->put_ok( "//$patron_userid:$password@/api/v1/public/lists/" . $unmodifiable_list->id => json => $update_data )
        ->status_is(
        403,
        "Cannot update list when allow_change_from_owner is false"
    )->json_is( '/error_code' => 'forbidden', 'Correct error code returned' );

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    $librarian->set_password( { password => $password, skip_validation => 1 } );
    my $librarian_userid = $librarian->userid;

    # Test librarian using public endpoint
    $t->put_ok( "//$librarian_userid:$password@/api/v1/public/lists/" . $modifiable_list->id => json => $update_data )
        ->status_is(
        403,
        'Librarian must use admin endpoint to modify others lists'
        );

    $schema->storage->txn_rollback;
};

subtest 'public_delete() tests' => sub {
    plan tests => 12;

    $schema->storage->txn_begin;

    my $password       = 'thePassword123';
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    $another_patron->set_password( { password => $password, skip_validation => 1 } );

    my $patron_userid         = $patron->userid;
    my $another_patron_userid = $another_patron->userid;

    # Create test lists for different scenarios
    my $modifiable_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron->id,
                public                  => 1,
                allow_change_from_owner => 1
            }
        }
    );

    my $other_patron_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $another_patron->id,
                public                  => 1,
                allow_change_from_owner => 1
            }
        }
    );

    my $unmodifiable_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron->id,
                public                  => 1,
                allow_change_from_owner => 0
            }
        }
    );

    # Test anonymous attempt
    $t->delete_ok( "/api/v1/public/lists/" . $modifiable_list->id )
        ->status_is( 401, 'Anonymous user cannot delete list' );

    # Test non-owner delete attempt
    $t->delete_ok( "//$another_patron_userid:$password@/api/v1/public/lists/" . $modifiable_list->id )
        ->status_is( 403, 'Non-owner cannot delete list' );

    # Test attempt to delete another patron's list
    $t->delete_ok( "//$patron_userid:$password@/api/v1/public/lists/" . $other_patron_list->id )
        ->status_is( 403, "Cannot delete another patron's list" );

    # Test delete of unmodifiable list
    $t->delete_ok( "//$patron_userid:$password@/api/v1/public/lists/" . $unmodifiable_list->id )->status_is(
        403,
        "Cannot delete list when allow_change_from_owner is false"
    );

    # Test delete of non-existent list
    $t->delete_ok("//$patron_userid:$password@/api/v1/public/lists/99999999")->status_is( 404, "List not found" );

    # Test successful delete by owner
    $t->delete_ok( "//$patron_userid:$password@/api/v1/public/lists/" . $modifiable_list->id )
        ->status_is( 204, 'List deleted successfully' );

    $schema->storage->txn_rollback;
};

1;
