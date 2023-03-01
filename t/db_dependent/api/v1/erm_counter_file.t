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

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::CounterFiles;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::CounterFiles->search->delete;

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
    # No counter files, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_files")->status_is(200)
      ->json_is( [] );

    my $counter_file =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );

    # One counter_file created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_files")->status_is(200)
      ->json_is( [ $counter_file->to_api ] );

    my $another_counter_file = $builder->build_object(
        {
            class => 'Koha::ERM::CounterFiles',
        }
    );

    # Two counter_files created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_files")->status_is(200)
      ->json_is(
        [
            $counter_file->to_api,
            $another_counter_file->to_api,
        ]
      );

    # Attempt to search by type like 'ko'
    $counter_file->delete;
    $another_counter_file->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/counter_files?q=[{"me.type":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $counter_file_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::CounterFiles',
            value => {
                type => 'koha',
            }
        }
    );

    # Search works, searching for type like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/counter_files?q=[{"me.type":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $counter_file_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_files?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/counter_files")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $counter_file =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );
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

    # This counter_file exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_files/"
          . $counter_file->erm_counter_files_id )->status_is(200)
      ->json_is( $counter_file->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/counter_files/"
          . $counter_file->erm_counter_files_id )->status_is(403);

    # Attempt to get non-existent counter_file
    my $counter_file_to_delete =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );
    my $non_existent_id = $counter_file_to_delete->erm_counter_files_id;
    $counter_file_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/counter_files/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Counter file not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 17;

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

    my $harvester =
      $builder->build_object( { class => 'Koha::ERM::Harvesters' } );

    my $counter_file = {
        harvester_id    => $harvester->erm_harvester_id,
        filename        => "test",
        file_content    => "lorem ipsum"
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/counter_files" => json =>
          $counter_file )->status_is(403);

    # Authorized attempt to write invalid data
    my $counter_file_with_invalid_field = {
        blah             => "Blah",
        harvester_id     => $harvester->erm_harvester_id,
        filename         => "test"
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/counter_files" => json =>
          $counter_file_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $counter_file_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_files" => json => $counter_file )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/counter_files/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/harvester_id'             => $counter_file->{harvester_id} )
      ->json_is( '/filename'     => $counter_file->{filename} )
      ->json_is( '/file_content'     => $counter_file->{file_content} )
      ->tx->res->json->{erm_counter_files_id};

    # Authorized attempt to create with null id
    $counter_file->{erm_counter_files_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_files" => json => $counter_file )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $counter_file->{erm_counter_files_id} = $counter_file_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_files" => json => $counter_file )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/erm_counter_files_id"
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

    my $harvester = $builder->build_object( { class => 'Koha::ERM::Harvesters' } );

    my $counter_file_id =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } )->erm_counter_files_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/counter_files/$counter_file_id" =>
          json => { type => 'New unauthorized type change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $counter_file_with_missing_field = {
        filename      => "test",
        file_content  => "lorem ipsum"
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_files/$counter_file_id" => json =>
          $counter_file_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/harvester_id" } ] );

    # Full object update on PUT
    my $counter_file_with_updated_field = {
        filename             => 'New filename',
        harvester_id         => $harvester->erm_harvester_id,
        file_content         => "lorem ipsum and some extra"
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_files/$counter_file_id" => json =>
          $counter_file_with_updated_field )->status_is(200)
      ->json_is( '/filename' => 'New filename' );

    # Authorized attempt to write invalid data
    my $counter_file_with_invalid_field = {
        blah             => "counter_file Blah",
        type             => "counter_file type",
        harvester_id      => $harvester->erm_harvester_id,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_files/$counter_file_id" => json =>
          $counter_file_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent counter_file
    my $counter_file_to_delete =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );
    my $non_existent_id = $counter_file_to_delete->erm_counter_files_id;
    $counter_file_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/counter_files/$non_existent_id" =>
          json => $counter_file_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $counter_file_with_updated_field->{erm_counter_files_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_files/$counter_file_id" => json =>
          $counter_file_with_updated_field )->status_is(404);

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

    my $counter_file_id =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } )->erm_counter_files_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/counter_files/$counter_file_id")
      ->status_is(403);

    # Delete existing counter_file
    $t->delete_ok("//$userid:$password@/api/v1/erm/counter_files/$counter_file_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent counter_file
    $t->delete_ok("//$userid:$password@/api/v1/erm/counter_files/$counter_file_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
