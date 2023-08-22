#!/usr/bin/env perl

# Copyright 2023 PTFS Europe

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
# along with Koha; if not, see <http://www.gusage_data_providers>.

use Modern::Perl;

use Test::More tests => 1;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ERM::UsageDataProviders;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'list() tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    Koha::ERM::UsageDataProviders->search->delete;

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
    # No usage_data_providers, so empty array should be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_data_providers")
      ->status_is(200)->json_is( [] );

    my $usage_data_provider =
      $builder->build_object( { class => 'Koha::ERM::UsageDataProviders' } );

    # One usage_data_provider created, should get returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_data_providers")
      ->status_is(200)->json_is( [ $usage_data_provider->to_api ] );

    my $another_usage_data_provider = $builder->build_object(
        {
            class => 'Koha::ERM::UsageDataProviders',
        }
    );

    # Two usage_data_providers created, they should both be returned
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_data_providers")
      ->status_is(200)
      ->json_is(
        [ $usage_data_provider->to_api, $another_usage_data_provider->to_api, ]
      );

    # Attempt to search by name like 'ko'
    $usage_data_provider->delete;
    $another_usage_data_provider->delete;
    $t->get_ok(
qq~//$userid:$password@/api/v1/erm/usage_data_providers?q=[{"me.name":{"like":"%ko%"}}]~
    )->status_is(200)->json_is( [] );

    my $usage_data_provider_to_search = $builder->build_object(
        {
            class => 'Koha::ERM::UsageDataProviders',
            value => {
                name => 'koha',
            }
        }
    );

    # Search works, searching for name like 'ko'
    $t->get_ok(
qq~//$userid:$password@/api/v1/erm/usage_data_providers?q=[{"me.name":{"like":"%ko%"}}]~
    )->status_is(200)->json_is( [ $usage_data_provider_to_search->to_api ] );

    # Warn on unsupported query parameter
    $t->get_ok("//$userid:$password@/api/v1/erm/usage_data_providers?blah=blah")
      ->status_is(400)
      ->json_is(
        [ { path => '/query/blah', message => 'Malformed query string' } ] );

    # Unauthorized access
    $t->get_ok("//$unauth_userid:$password@/api/v1/erm/usage_data_providers")
      ->status_is(403);

    $schema->storage->txn_rollback;
};
