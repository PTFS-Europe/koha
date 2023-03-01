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

use Koha::ERM::ReportTypes;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::ReportTypes->search->delete;

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
    # No report types, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/report_types")->status_is(200)
      ->json_is( [] );

    my $report_type =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } );

    # One report_type created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/report_types")->status_is(200)
      ->json_is( [ $report_type->to_api ] );

    my $another_report_type = $builder->build_object(
        {
            class => 'Koha::ERM::ReportTypes',
        }
    );

    # Two report_types created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/report_types")->status_is(200)
      ->json_is(
        [
            $report_type->to_api,
            $another_report_type->to_api,
        ]
      );

    # Attempt to search by type like 'ko'
    $report_type->delete;
    $another_report_type->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/report_types?q=[{"me.type":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $report_type_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::ReportTypes',
            value => {
                type => 'koha',
            }
        }
    );

    # Search works, searching for type like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/report_types?q=[{"me.type":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $report_type_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/report_types?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/report_types")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $report_type =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } );
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

    # This report_type exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/report_types/"
          . $report_type->erm_report_id )->status_is(200)
      ->json_is( $report_type->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/report_types/"
          . $report_type->erm_report_id )->status_is(403);

    # Attempt to get non-existent report_type
    my $report_type_to_delete =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } );
    my $non_existent_id = $report_type_to_delete->erm_report_id;
    $report_type_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/report_types/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Report type not found' );

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

    my $harvester = $builder->build_object( { class => 'Koha::ERM::Harvesters' } );

    my $report_type = {
        harvester_id    => $harvester->erm_harvester_id,
        type            => "test"
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/report_types" => json =>
          $report_type )->status_is(403);

    # Authorized attempt to write invalid data
    my $report_type_with_invalid_field = {
        blah             => "report_type Blah",
        harvester_id     => $harvester->erm_harvester_id,
        type             => "test"
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/report_types" => json =>
          $report_type_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $report_type_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/report_types" => json => $report_type )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/report_types/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/harvester_id'             => $report_type->{harvester_id} )
      ->json_is( '/type'     => $report_type->{type} )
      ->tx->res->json->{erm_report_id};

    # Authorized attempt to create with null id
    $report_type->{erm_report_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/report_types" => json => $report_type )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $report_type->{erm_report_id} = $report_type_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/report_types" => json => $report_type )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/erm_report_id"
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

    my $report_type_id =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } )->erm_report_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/report_types/$report_type_id" =>
          json => { type => 'New unauthorized type change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $report_type_with_missing_field = {
        type      => "test",
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/report_types/$report_type_id" => json =>
          $report_type_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/harvester_id" } ] );

    # Full object update on PUT
    my $report_type_with_updated_field = {
        type             => 'New type',
        harvester_id      => $harvester->erm_harvester_id,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/report_types/$report_type_id" => json =>
          $report_type_with_updated_field )->status_is(200)
      ->json_is( '/type' => 'New type' );

    # Authorized attempt to write invalid data
    my $report_type_with_invalid_field = {
        blah             => "report_type Blah",
        type             => "report_type type",
        harvester_id      => $harvester->erm_harvester_id,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/report_types/$report_type_id" => json =>
          $report_type_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent report_type
    my $report_type_to_delete =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } );
    my $non_existent_id = $report_type_to_delete->erm_report_id;
    $report_type_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/report_types/$non_existent_id" =>
          json => $report_type_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $report_type_with_updated_field->{erm_report_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/report_types/$report_type_id" => json =>
          $report_type_with_updated_field )->status_is(404);

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

    my $report_type_id =
      $builder->build_object( { class => 'Koha::ERM::ReportTypes' } )->erm_report_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/report_types/$report_type_id")
      ->status_is(403);

    # Delete existing report_type
    $t->delete_ok("//$userid:$password@/api/v1/erm/report_types/$report_type_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent report_type
    $t->delete_ok("//$userid:$password@/api/v1/erm/report_types/$report_type_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
