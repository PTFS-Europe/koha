#!/usr/bin/env perl

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;
use Data::Dumper;

use JSON qw(encode_json);

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Virtualshelves;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {
    plan tests => 7;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $patron_userid    = $patron->userid;

    # Create test lists owned by different users
    my $list_1 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 1 }
        }
    );
    my $list_2 = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id, public => 0 }
        }
    );

    my $q = encode_json( { list_id => { -in => [ $list_1->id, $list_2->id, ] } } );

    # Test unauthorized access
    $t->get_ok("/api/v1/lists?q=$q")->status_is( 401, "Anonymous users cannot access admin lists endpoint" );

    $t->get_ok("//$patron_userid:$password@/api/v1/lists?q=$q")
        ->status_is( 403, "Regular patrons cannot access admin lists endpoint" );

    # Test authorized access - use to_api method which is already tested
    my $expected = [ $list_1->to_api, $list_2->to_api ];

    $t->get_ok("//$librarian_userid:$password@/api/v1/lists?q=$q")->status_is(200)->json_is($expected);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan tests => 11;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $patron_userid    = $patron->userid;

    # Create test lists with different attributes
    my $public_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $librarian->id,
                public                  => 1,
                allow_change_from_owner => 1
            }
        }
    );

    my $private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $patron->id,
                public                  => 0,
                allow_change_from_owner => 0
            }
        }
    );

    my $another_private_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $another_patron->id,
                public                  => 0,
                allow_change_from_owner => 0
            }
        }
    );

    # Test unauthorized access
    $t->get_ok( "/api/v1/lists/" . $public_list->id )
        ->status_is( 401, "Anonymous users cannot access admin lists endpoint" );

    # Test access without permission
    $t->get_ok( "//$patron_userid:$password@/api/v1/lists/" . $public_list->id )
        ->status_is( 403, "Regular patrons cannot access admin lists endpoint" );

    # Test authorized access to public list
    $t->get_ok( "//$librarian_userid:$password@/api/v1/lists/" . $public_list->id )->status_is(200)
        ->json_is( $public_list->to_api );

    # Test authorized access to another patron's private list
    $t->get_ok( "//$librarian_userid:$password@/api/v1/lists/" . $private_list->id )->status_is(
        403,
        "Librarian cannot access private lists they don't own"
    );

    # Test non-existent list
    $t->get_ok("//$librarian_userid:$password@/api/v1/lists/99999999")->status_is( 404, "List not found" );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan tests => 16;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $patron_userid    = $patron->userid;

    # Test unauthorized access
    my $list_data = {
        name                    => "Test List",
        owner_id                => $librarian->id,
        public                  => 1,
        allow_change_from_owner => 1, allow_change_from_others => 0,
        default_sort_field      => 'title'
    };

    $t->post_ok( "/api/v1/lists" => json => $list_data )->status_is( 401, "Anonymous users cannot create lists" );

    $t->post_ok( "//$patron_userid:$password@/api/v1/lists" => json => $list_data )
        ->status_is( 403, "Regular patrons cannot create lists" );

    # Test authorized creation - list for self
    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_data )->status_is(201)->header_like(
        Location => qr|^/api/v1/lists/\d+|,
        'Location header is correct'
    )->json_has( '/list_id', 'List ID is present in response' )
        ->json_has( '/name', 'List name is present in response' );

    # Test authorized creation - list for another patron
    my $list_for_patron = {
        name                     => "Test List for Patron",
        owner_id                 => $another_patron->id,
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_for_patron )->status_is(201)->json_is(
        '/owner_id' => $another_patron->id,
        'List created with correct owner'
    )->json_is( '/name' => 'Test List for Patron', 'List name set correctly' );

    # Test creating list with invalid owner_id
    my $list_invalid_owner = {
        name                     => "Test List",
        owner_id                 => 999999,        # Non-existent patron id
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->post_ok( "//$librarian_userid:$password@/api/v1/lists" => json => $list_invalid_owner )->status_is(400)
        ->json_like( '/error' => qr/Invalid owner_id/ );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {
    plan tests => 27;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    my $patron         = $builder->build_object( { class => 'Koha::Patrons' } );
    my $another_patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $patron_userid    = $patron->userid;

    # Create test list
    my $list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $librarian->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0
            }
        }
    );

    # Test unauthorized access
    my $update_data = {
        name                     => "Updated List Name 1",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "/api/v1/lists/" . $list->id => json => $update_data )
        ->status_is( 401, "Anonymous users cannot update lists" );

    $t->put_ok( "//$patron_userid:$password@/api/v1/lists/" . $list->id => json => $update_data )
        ->status_is( 403, "Regular patrons cannot update lists" );

    # Test successful update
    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id => json => $update_data )->status_is(200)
        ->json_is(
        '/name' => 'Updated List Name 1',
        'List name updated correctly'
    )->json_is( '/public' => 0, 'List privacy updated correctly' );

    # Test update of non-existent list
    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/99999999" => json => $update_data )
        ->status_is( 404, "Attempting to update non-existent list returns 404" );

    # Test partial update - changed to include all required fields
    my $partial_update = {
        name                     => "Updated List Name 2",
        public                   => 1,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id => json => $partial_update )->status_is(200)
        ->json_is( '/name' => "Updated List Name 2", "Update successful" );

    # Test updating another patron's list with librarian permissions
    my $patron_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 1,
                allow_change_from_staff  => 1
            }
        }
    );

    my $update_data_2 = {
        name                     => "Updated List Name 3",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_list->id => json => $update_data_2 )
        ->status_is(200)->json_is( '/name' => 'Updated List Name 3', 'Librarian can update other patron\'s list' );

    # Test librarian updating their own list
    my $librarian_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                   => $librarian->id,
                public                  => 1,
                allow_change_from_owner => 0               # Even librarian should respect this flag for their own lists
            }
        }
    );

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $librarian_list->id => json => $update_data )
        ->status_is(
        403,
        "Even librarians must respect allow_change_from_owner for their own lists"
        );

    # Test update with allow_change_from_staff permission
    my $list_staff = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0,
                allow_change_from_staff  => 1
            }
        }
    );

    my $update_data_3 = {
        name                     => "Updated List Name 4",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list_staff->id => json => $update_data_3 )
        ->status_is(200)
        ->json_is( '/name' => 'Updated List Name 4', 'Staff can update list with allow_change_from_staff' );

    # Test updating list with no permissions
    my $no_permission_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0,
                allow_change_from_staff  => 0
            }
        }
    );

    my $update_data_4 = {
        name                     => "Updated List Name 5",
        public                   => 0,
        allow_change_from_owner  => 1,
        allow_change_from_others => 0,
        default_sort_field       => 'title'
    };

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $no_permission_list->id => json => $update_data_4 )
        ->status_is(403)->json_is( '/error' => 'Cannot modify list without proper permissions' );

    # Test update when both permission flags are false
    my $no_perm_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0,
                allow_change_from_staff  => 0
            }
        }
    );

    $t->put_ok( "//$librarian_userid:$password@/api/v1/lists/" . $no_perm_list->id => json => $update_data )
        ->status_is(403)->json_is( '/error' => 'Cannot modify list without proper permissions' );

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {
    plan tests => 16;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';

    # Create librarian with necessary permissions
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**13 }
        }
    );
    my $patron = $builder->build_object( { class => 'Koha::Patrons' } );

    $librarian->set_password( { password => $password, skip_validation => 1 } );
    $patron->set_password( { password => $password, skip_validation => 1 } );

    my $librarian_userid = $librarian->userid;
    my $patron_userid    = $patron->userid;

    # Create test list
    my $list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $librarian->id }
        }
    );

    # Test unauthorized access
    $t->delete_ok( "/api/v1/lists/" . $list->id )->status_is( 401, "Anonymous users cannot delete lists" );

    $t->delete_ok( "//$patron_userid:$password@/api/v1/lists/" . $list->id )
        ->status_is( 403, "Regular patrons cannot delete lists" );

    # Test successful delete
    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list->id )
        ->status_is( 204, "List deleted successfully" );

    # Test non-existent list
    $t->delete_ok("//$librarian_userid:$password@/api/v1/lists/99999999")
        ->status_is( 404, "Attempting to delete non-existent list returns 404" );

    # Test deleting another patron's list with librarian permissions
    my $patron_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => { owner => $patron->id }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $patron_list->id )
        ->status_is( 204, "Librarian can delete other patron's list" );

    # Test deleting list with allow_change_from_staff permission
    my $list_staff = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0,
                allow_change_from_staff  => 1
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list_staff->id )
        ->status_is( 204, "Staff can delete list with allow_change_from_staff" );

    # Test deleting list with allow_change_from_others permission
    my $list_others = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 1,
                allow_change_from_staff  => 0
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $list_others->id )
        ->status_is( 204, "Can delete list with allow_change_from_others" );

    # Test deleting list with no permissions
    my $no_permission_list = $builder->build_object(
        {
            class => 'Koha::Virtualshelves',
            value => {
                owner                    => $patron->id,
                public                   => 1,
                allow_change_from_owner  => 1,
                allow_change_from_others => 0,
                allow_change_from_staff  => 0
            }
        }
    );

    $t->delete_ok( "//$librarian_userid:$password@/api/v1/lists/" . $no_permission_list->id )
        ->status_is( 403, "Cannot delete list without proper permissions" );

    $schema->storage->txn_rollback;
};

1;
