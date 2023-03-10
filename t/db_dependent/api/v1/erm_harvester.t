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
# along with Koha; if not, see <http://www.gnu.org/harvesters>.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::Harvesters;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::Harvesters->search->delete;

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
    # No harvesters, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/harvesters")->status_is(200)
      ->json_is( [] );

    my $harvester =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } );

    # One harvester created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/harvesters")->status_is(200)
      ->json_is( [ $harvester->to_api ] );

    my $another_harvester = $builder->build_object(
        {
            class => 'Koha::ERM::Harvesters',
        }
    );

    # Two harvesters created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/harvesters")->status_is(200)
      ->json_is(
        [
            $harvester->to_api,
            $another_harvester->to_api,
        ]
      );

    # Attempt to search by name like 'ko'
    $harvester->delete;
    $another_harvester->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/harvesters?q=[{"me.platform":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $harvester_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::Harvesters',
            value => {
                platform => 'koha',
            }
        }
    );

    # Search works, searching for name like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/harvesters?q=[{"me.platform":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $harvester_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/harvesters?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/harvesters")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $harvester =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } );
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

    # This harvester exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/harvesters/"
          . $harvester->erm_harvester_id )->status_is(200)
      ->json_is( $harvester->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/harvesters/"
          . $harvester->erm_harvester_id )->status_is(403);

    # Attempt to get non-existent harvester
    my $harvester_to_delete =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } );
    my $non_existent_id = $harvester_to_delete->erm_harvester_id;
    $harvester_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/harvesters/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Harvester not found' );

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

    my $platform = $builder->build_object( { class => 'Koha::ERM::Platforms' } );

    my $harvester = {
        platform_id      => $platform->{erm_platform_id},
        status           => "active",
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/harvesters" => json =>
          $harvester )->status_is(403);

    # Authorized attempt to write invalid data
    my $harvester_with_invalid_field = {
        blah             => "Harvester Blah",
        platform_id      => $platform->{erm_platform_id},
        status           => "active",
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/harvesters" => json =>
          $harvester_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $erm_harvester_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/harvesters" => json => $harvester )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/harvesters/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/platform_id' => $harvester->{platform_id} )
      ->json_is( '/status'     => $harvester->{status} )
      ->tx->res->json->{erm_harvester_id};

    # Authorized attempt to create with null id
    $harvester->{erm_harvester_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/harvesters" => json => $harvester )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $harvester->{erm_harvester_id} = $erm_harvester_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/harvesters" => json => $harvester )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/erm_harvester_id"
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

    my $platform = $builder->build_object( { class => 'Koha::ERM::Platforms' } );

    my $erm_harvester_id =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } )->erm_harvester_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/harvesters/$erm_harvester_id" =>
          json => { platform_id => 1, status => "active" } )->status_is(403);

    # Attempt partial update on a PUT
    my $harvester_with_missing_field = {
        status           => 'active',
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id" => json =>
          $harvester_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/platform_id" } ] );

    # Full object update on PUT
    my $harvester_with_updated_field = {
        platform_id      => $platform->{erm_platform_id},
        status           => 'expired',
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id" => json =>
          $harvester_with_updated_field )->status_is(200)
      ->json_is( '/status' => 'expired' );

    # Authorized attempt to write invalid data
    my $harvester_with_invalid_field = {
        blah             => "Harvester Blah",
        platform_id      => $platform->{erm_platform_id},
        status           => 'expired',
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id" => json =>
          $harvester_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent harvester
    my $harvester_to_delete =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } );
    my $non_existent_id = $harvester_to_delete->id;
    $harvester_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/harvesters/$non_existent_id" =>
          json => $harvester_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $harvester_with_updated_field->{erm_harvester_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id" => json =>
          $harvester_with_updated_field )->status_is(404);

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

    my $erm_harvester_id =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } )->erm_harvester_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/harvesters/$erm_harvester_id")
      ->status_is(403);

    # Delete existing harvester
    $t->delete_ok("//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent harvester
    $t->delete_ok("//$userid:$password@/api/v1/erm/harvesters/$erm_harvester_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
