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

use Koha::ERM::CounterLogs;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::CounterLogs->search->delete;

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
    # No counter logs, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")->status_is(200)
      ->json_is( [] );

    my $counter_log =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } );

    # One counter_log created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")->status_is(200)
      ->json_is( [ $counter_log->to_api ] );

    my $another_counter_log = $builder->build_object(
        {
            class => 'Koha::ERM::CounterLogs',
        }
    );

    # Two counter_logs created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs")->status_is(200)
      ->json_is(
        [
            $counter_log->to_api,
            $another_counter_log->to_api,
        ]
      );

    # Attempt to search by filename like 'ko'
    $counter_log->delete;
    $another_counter_log->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/counter_logs?q=[{"me.filename":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $counter_log_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::CounterLogs',
            value => {
                filename => 'koha',
            }
        }
    );

    # Search works, searching for filename like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/counter_logs?q=[{"me.filename":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $counter_log_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/counter_logs")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $counter_log =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } );
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

    # This counter_log exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/counter_logs/"
          . $counter_log->erm_counter_log_id )->status_is(200)
      ->json_is( $counter_log->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/counter_logs/"
          . $counter_log->erm_counter_log_id )->status_is(403);

    # Attempt to get non-existent counter_log
    my $counter_log_to_delete =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } );
    my $non_existent_id = $counter_log_to_delete->erm_counter_log_id;
    $counter_log_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/counter_logs/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Counter log not found' );

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

    my $counter_file =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );

    my $counter_log = {
        counter_files_id    => $counter_file->{erm_counter_files_id},
        filename            => "test",
        borrowernumber      => $librarian->{borrowernumber}
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/counter_logs" => json =>
          $counter_log )->status_is(403);

    # Authorized attempt to write invalid data
    my $counter_log_with_invalid_field = {
        blah                 => "counter_log Blah",
        counter_files_id     => 1,
        filename             => "test"
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/counter_logs" => json =>
          $counter_log_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $counter_log_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_logs" => json => $counter_log )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/counter_logs/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/counter_files_id'      => $counter_log->{counter_files_id} )
      ->json_is( '/filename'     => $counter_log->{filename} )
      ->json_is( '/borrowernumber'     => $counter_log->{borrowernumber} )
      ->tx->res->json->{erm_counter_log_id};

    # Authorized attempt to create with null id
    $counter_log->{erm_counter_log_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_logs" => json => $counter_log )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $counter_log->{erm_counter_log_id} = $counter_log_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_logs" => json => $counter_log )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/erm_counter_log_id"
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

    my $counter_file =
      $builder->build_object( { class => 'Koha::ERM::CounterFiles' } );

    my $counter_log_id =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } )->erm_counter_log_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/counter_logs/$counter_log_id" =>
          json => { type => 'New unauthorized type change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $counter_log_with_missing_field = {
        filename        => "test",
        borrowernumber  => $librarian->{borrowernumber}
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id" => json =>
          $counter_log_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/counter_files_id" } ] );

    # Full object update on PUT
    my $counter_log_with_updated_field = {
        filename                 => 'New filename',
        counter_files_id         => $counter_file->{erm_counter_files_id},
        borrowernumber           => $librarian->{borrowernumber}
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id" => json =>
          $counter_log_with_updated_field )->status_is(200)
      ->json_is( '/filename' => 'New filename' );

    # Authorized attempt to write invalid data
    my $counter_log_with_invalid_field = {
        blah                  => "counter_log Blah",
        counter_files_id      => 1,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id" => json =>
          $counter_log_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent counter_log
    my $counter_log_to_delete =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } );
    my $non_existent_id = $counter_log_to_delete->erm_counter_log_id;
    $counter_log_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/counter_logs/$non_existent_id" =>
          json => $counter_log_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $counter_log_with_updated_field->{erm_counter_log_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id" => json =>
          $counter_log_with_updated_field )->status_is(404);

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

    my $counter_log_id =
      $builder->build_object( { class => 'Koha::ERM::CounterLogs' } )->erm_counter_log_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/counter_logs/$counter_log_id")
      ->status_is(403);

    # Delete existing counter_log
    $t->delete_ok("//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent counter_log
    $t->delete_ok("//$userid:$password@/api/v1/erm/counter_logs/$counter_log_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
