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
# along with Koha; if not, see <http://www.gusage_titles>.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::UsageTitles;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::UsageTitles->search->delete;

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
    # No titles, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_titles")->status_is(200)
      ->json_is( [] );

    my $usage_title =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );

    # One usage_title created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_titles")->status_is(200)
      ->json_is( [ $usage_title->to_api ] );

    my $another_usage_title = $builder->build_object(
        {
            class => 'Koha::ERM::UsageTitles',
        }
    );

    # Two usage_titles created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_titles")->status_is(200)
      ->json_is(
        [
            $usage_title->to_api,
            $another_usage_title->to_api,
        ]
      );

    # Attempt to search by title like 'ko'
    $usage_title->delete;
    $another_usage_title->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/usage_titles?q=[{"me.title":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $usage_title_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::UsageTitles',
            value => {
                title => 'koha',
            }
        }
    );

    # Search works, searching for title like 'ko'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/usage_titles?q=[{"me.title":{"like":"%ko%"}}]~)
      ->status_is(200)
      ->json_is( [ $usage_title_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_titles?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/usage_titles")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $usage_title =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );
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

    # This usage_title exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/usage_titles/"
          . $usage_title->title_id )->status_is(200)
      ->json_is( $usage_title->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/usage_titles/"
          . $usage_title->title_id )->status_is(403);

    # Attempt to get non-existent usage_title
    my $usage_title_to_delete =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );
    my $non_existent_id = $usage_title_to_delete->title_id;
    $usage_title_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/usage_titles/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Usage title not found' );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

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

    my $usage_data_provider =
      $builder->build_object( { class => 'Koha::ERM::UsageDataProviders' } );

    my $usage_title = {
        title                     => "usage_title title",
        usage_data_provider_id    => $usage_data_provider->erm_usage_data_provider_id,
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/usage_titles" => json =>
          $usage_title )->status_is(403);

    # Authorized attempt to write invalid data
    my $usage_title_with_invalid_field = {
        blah             => "usage_title Blah",
        title            => "usage_title title",
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/usage_titles" => json =>
          $usage_title_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $usage_title_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/usage_titles" => json => $usage_title )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/usage_titles/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/title'     => $usage_title->{title} )
      ->tx->res->json->{title_id};

    # Authorized attempt to create with null id
    $usage_title->{title_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/usage_titles" => json => $usage_title )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $usage_title->{title_id} = $usage_title_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/usage_titles" => json => $usage_title )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/title_id"
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

    my $usage_data_provider =
      $builder->build_object( { class => 'Koha::ERM::UsageDataProviders' } );

    my $usage_title_id =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } )->title_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/usage_titles/$usage_title_id" =>
          json => { name => 'New unauthorized name change' } )->status_is(403);

    # Attempt partial update on a PUT
    my $usage_title_with_missing_field = {
        usage_data_provider_id    => $usage_data_provider->erm_usage_data_provider_id
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id" => json =>
          $usage_title_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/title" } ] );

    # Full object update on PUT
    my $usage_title_with_updated_field = {
        title      => 'New title',
        usage_data_provider_id    => $usage_data_provider->erm_usage_data_provider_id,
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id" => json =>
          $usage_title_with_updated_field )->status_is(200)
      ->json_is( '/title' => 'New title' );

    # Authorized attempt to write invalid data
    my $usage_title_with_invalid_field = {
        blah             => "usage_title Blah",
        title            => "usage_title title",
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id" => json =>
          $usage_title_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent usage_title
    my $usage_title_to_delete =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );
    my $non_existent_id = $usage_title_to_delete->title_id;
    $usage_title_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/usage_titles/$non_existent_id" =>
          json => $usage_title_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $usage_title_with_updated_field->{title_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id" => json =>
          $usage_title_with_updated_field )->status_is(404);

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

    my $usage_title_id =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } )->title_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/usage_titles/$usage_title_id")
      ->status_is(403);

    # Delete existing usage_title
    $t->delete_ok("//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent usage_title
    $t->delete_ok("//$userid:$password@/api/v1/erm/usage_titles/$usage_title_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
