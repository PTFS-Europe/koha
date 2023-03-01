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
# along with Koha; if not, see <http://www.gplatforms>.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::Platforms;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::Platforms->search->delete;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
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

    ## Authorized user tests
    # No platforms, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/platforms")->status_is(200)
      ->json_is( [] );

    my $platform =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );

    # One platform created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/platforms")->status_is(200)
      ->json_is( [ $platform->to_api ] );

    my $another_platform = $builder->build_object(
        {
            class => 'Koha::ERM::Platforms',
        }
    );

    # Two platforms created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/platforms")->status_is(200)
      ->json_is(
        [
            $platform->to_api,
            $another_platform->to_api,
        ]
      );

    # Attempt to search by name like 'ko'
    $platform->delete;
    $another_platform->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/platforms?q=[{"me.name":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $platform_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::Platforms',
            value => {
                name => 'koha',
            }
        }
    );

    # Search works, searching for name like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/platforms?q=[{"me.name":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $platform_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/platforms?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/platforms")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $platform =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );
    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
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

    # This platform exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/platforms/"
          . $platform->erm_platform_id )->status_is(200)
      ->json_is( $platform->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/platforms/"
          . $platform->erm_platform_id )->status_is(403);

    # Attempt to get non-existent platform
    my $platform_to_delete =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );
    my $non_existent_id = $platform_to_delete->erm_platform_id;
    $platform_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/platforms/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Platform not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 16;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
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

    my $platform = {
        name             => "platform name",
        description      => "platform description",
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/platforms" => json =>
          $platform )->status_is(403);

    # Authorized attempt to write invalid data
    my $platform_with_invalid_field = {
        blah             => "platform Blah",
        name             => "platform name",
        description      => "platform description",
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/platforms" => json =>
          $platform_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $platform_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/platforms" => json => $platform )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/platforms/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/name'             => $platform->{name} )
      ->json_is( '/description'     => $platform->{description} )
      ->tx->res->json->{erm_platform_id};

    # Authorized attempt to create with null id
    $platform->{erm_platform_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/platforms" => json => $platform )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $platform->{erm_platform_id} = $platform_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/platforms" => json => $platform )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/erm_platform_id"
            }
        ]
      );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
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

    my $platform_id =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } )->erm_platform_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/platforms/$platform_id" =>
          json => { name => 'New unauthorized name change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $platform_with_missing_field = {
        description      => 'New description',
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/platforms/$platform_id" => json =>
          $platform_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/name" } ] );

    # Full object update on PUT
    my $platform_with_updated_field = {
        name             => 'New name',
        description      => 'New description',
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/platforms/$platform_id" => json =>
          $platform_with_updated_field )->status_is(200)
      ->json_is( '/name' => 'New name' );

    # Authorized attempt to write invalid data
    my $platform_with_invalid_field = {
        blah             => "platform Blah",
        name             => "platform name",
        description      => "platform description",
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/platforms/$platform_id" => json =>
          $platform_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent platform
    my $platform_to_delete =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );
    my $non_existent_id = $platform_to_delete->erm_platform_id;
    $platform_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/platforms/$non_existent_id" =>
          json => $platform_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $platform_with_updated_field->{erm_platform_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/platforms/$platform_id" => json =>
          $platform_with_updated_field )->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my $librarian = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**28 }
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

    my $platform_id =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } )->erm_platform_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/platforms/$platform_id")
      ->status_is(403);

    # Delete existing platform
    $t->delete_ok("//$userid:$password@/api/v1/erm/platforms/$platform_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent platform
    $t->delete_ok("//$userid:$password@/api/v1/erm/platforms/$platform_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
