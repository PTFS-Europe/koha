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
# along with Koha; if not, see <http://www.gyearly_usage_summarys>.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::YearlyUsages;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::YearlyUsages->search->delete;

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
    $t->get_ok("//$userid:$password@/api/v1/erm/yearly_usage")->status_is(200)
      ->json_is( [] );

    my $yearly_usage_summary =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } );

    # One yearly_usage_summary created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/yearly_usage")->status_is(200)
      ->json_is( [ $yearly_usage_summary->to_api ] );

    my $another_yearly_usage_summary = $builder->build_object(
        {
            class => 'Koha::ERM::YearlyUsages',
        }
    );

    # Two yearly_usage_summarys created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/yearly_usage")->status_is(200)
      ->json_is(
        [
            $yearly_usage_summary->to_api,
            $another_yearly_usage_summary->to_api,
        ]
      );

    # Attempt to search by year like '20'
    $yearly_usage_summary->delete;
    $another_yearly_usage_summary->delete;
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/yearly_usage?q=[{"me.year":{"like":"%20%"}}]~)
      ->status_is(200)
      ->json_is( [] );

    my $yearly_usage_summary_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::YearlyUsages',
            value => {
                year => '2020',
            }
        }
    );

    # Search works, searching for year like '20'
    $t->get_ok( qq~//$userid:$password@/api/v1/erm/yearly_usage?year=2020~)
      ->status_is(200)
      ->json_is( [ $yearly_usage_summary_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/yearly_usage?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/yearly_usage")
      ->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 8;

    $schema->storage->txn_begin;

    my $yearly_usage_summary =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } );
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

    # This yearly_usage_summary exists, should get returned
    $t->get_ok( "//$userid:$password@/api/v1/erm/yearly_usage/"
          . $yearly_usage_summary->yearly_usage_summary_id )->status_is(200)
      ->json_is( $yearly_usage_summary->to_api );

    # Unauthorized access
    $t->get_ok( "//$unauth_userid:$password@/api/v1/erm/yearly_usage/"
          . $yearly_usage_summary->title_id )->status_is(403);

    # Attempt to get non-existent yearly_usage_summary
    my $yearly_usage_summary_to_delete =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } );
    my $non_existent_id = $yearly_usage_summary_to_delete->title_id;
    $yearly_usage_summary_to_delete->delete;

    $t->get_ok("//$userid:$password@/api/v1/erm/yearly_usage/$non_existent_id")
      ->status_is(404)->json_is( '/error' => 'Yearly usage summary not found' );

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

    my $platform =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );

    my $usage_title =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );

    my $yearly_usage_summary = {
        platform_id      => $platform->{erm_platform_id},
        title_id         => $usage_title->{title_id}
    };

    # Unauthorized attempt to write
    $t->post_ok( "//$unauth_userid:$password@/api/v1/erm/yearly_usage" => json =>
          $yearly_usage_summary )->status_is(403);

    # Authorized attempt to write invalid data
    my $yearly_usage_summary_with_invalid_field = {
        blah             => "yearly_usage_summary Blah",
        platform_id      => $platform->{erm_platform_id},
        title_id         => $usage_title->{title_id}
    };

    $t->post_ok( "//$userid:$password@/api/v1/erm/yearly_usage" => json =>
          $yearly_usage_summary_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Authorized attempt to write
    my $yearly_usage_summary_id =
      $t->post_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage" => json => $yearly_usage_summary )
      ->status_is( 201, 'SWAGGER3.2.1' )->header_like(
        Location => qr|^/api/v1/erm/yearly_usage/\d*|,
        'SWAGGER3.4.1'
    )->json_is( '/platform_id'     => $yearly_usage_summary->{platform_id} )
    ->json_is( '/title_id'     => $yearly_usage_summary->{title_id} )
      ->tx->res->json->{yearly_usage_summary_id};

    # Authorized attempt to create with null id
    $yearly_usage_summary->{yearly_usage_summary_id} = undef;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage" => json => $yearly_usage_summary )
      ->status_is(400)->json_has('/errors');

    # Authorized attempt to create with existing id
    $yearly_usage_summary->{yearly_usage_summary_id} = $yearly_usage_summary_id;
    $t->post_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage" => json => $yearly_usage_summary )
      ->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/yearly_usage_summary_id"
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

    my $platform =
      $builder->build_object( { class => 'Koha::ERM::Platforms' } );

    my $usage_title =
      $builder->build_object( { class => 'Koha::ERM::UsageTitles' } );

    my $yearly_usage_summary_id =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } )->yearly_usage_summary_id;

    # Unauthorized attempt to update
    $t->put_ok(
        "//$unauth_userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id" =>
          json => { year => 2023 } )->status_is(403);

    # Attempt partial update on a PUT
    my $yearly_usage_summary_with_missing_field = {
        platform_id   => $platform->{erm_platform_id}
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id" => json =>
          $yearly_usage_summary_with_missing_field )->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/title_id" } ] );

    # Full object update on PUT
    my $yearly_usage_summary_with_updated_field = {
        title_id      => $usage_title->{title_id},
        platform_id   => $platform->{erm_platform_id},
        year          => 2019
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id" => json =>
          $yearly_usage_summary_with_updated_field )->status_is(200)
      ->json_is( '/year' => 2019 );

    # Authorized attempt to write invalid data
    my $yearly_usage_summary_with_invalid_field = {
        blah             => "yearly_usage_summary Blah",
    };

    $t->put_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id" => json =>
          $yearly_usage_summary_with_invalid_field )->status_is(400)->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
          );

    # Attempt to update non-existent yearly_usage_summary
    my $yearly_usage_summary_to_delete =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } );
    my $non_existent_id = $yearly_usage_summary_to_delete->yearly_usage_summary_id;
    $yearly_usage_summary_to_delete->delete;

    $t->put_ok( "//$userid:$password@/api/v1/erm/yearly_usage/$non_existent_id" =>
          json => $yearly_usage_summary_with_updated_field )->status_is(404);

    # Wrong method (POST)
    $yearly_usage_summary_with_updated_field->{yearly_usage_summary_id} = 2;

    $t->post_ok(
        "//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id" => json =>
          $yearly_usage_summary_with_updated_field )->status_is(404);

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

    my $yearly_usage_summary_id =
      $builder->build_object( { class => 'Koha::ERM::YearlyUsages' } )->yearly_usage_summary_id;

    # Unauthorized attempt to delete
    $t->delete_ok(
        "//$unauth_userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id")
      ->status_is(403);

    # Delete existing yearly_usage_summary
    $t->delete_ok("//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id")
      ->status_is( 204, 'SWAGGER3.2.4' )->content_is( '', 'SWAGGER3.3.4' );

    # Attempt to delete non-existent yearly_usage_summary
    $t->delete_ok("//$userid:$password@/api/v1/erm/yearly_usage/$yearly_usage_summary_id")
      ->status_is(404);

    $schema->storage->txn_rollback;
};
