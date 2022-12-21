#!/usr/bin/env perl

# Copyright 2016 Koha-Suomi
#
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

use Test::More tests => 3;
use Test::Mojo;
use Test::Warn;

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Auth;
use Koha::Items;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

subtest 'list() tests' => sub {

    plan tests => 12;

    $schema->storage->txn_begin;

    my $item   = $builder->build_sample_item;
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 4 }
        }
    );

    # Make sure we have at least 10 items
    for ( 1..10 ) {
        $builder->build_sample_item;
    }

    my $nonprivilegedpatron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );

    my $password = 'thePassword123';

    $nonprivilegedpatron->set_password(
        { password => $password, skip_validation => 1 } );
    my $userid = $nonprivilegedpatron->userid;

    $t->get_ok( "//$userid:$password@/api/v1/items" )
      ->status_is(403)
      ->json_is(
        '/error' => 'Authorization failure. Missing required permission(s).' );

    $patron->set_password( { password => $password, skip_validation => 1 } );
    $userid = $patron->userid;

    $t->get_ok( "//$userid:$password@/api/v1/items?_per_page=10" )
      ->status_is( 200, 'SWAGGER3.2.2' );

    my $response_count = scalar @{ $t->tx->res->json };

    is( $response_count, 10, 'The API returns 10 items' );

    $t->get_ok( "//$userid:$password@/api/v1/items?external_id=" . $item->barcode )
      ->status_is(200)
      ->json_is( '' => [ $item->to_api ], 'SWAGGER3.3.2');

    my $barcode = $item->barcode;
    $item->delete;

    $t->get_ok( "//$userid:$password@/api/v1/items?external_id=" . $item->barcode )
      ->status_is(200)
      ->json_is( '' => [] );

    $schema->storage->txn_rollback;
};


subtest 'get() tests' => sub {

    plan tests => 17;

    $schema->storage->txn_begin;

    my $item = $builder->build_sample_item;
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 4 }
    });

    my $nonprivilegedpatron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 0 }
    });

    my $password = 'thePassword123';

    $nonprivilegedpatron->set_password({ password => $password, skip_validation => 1 });
    my $userid = $nonprivilegedpatron->userid;

    $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->itemnumber )
      ->status_is(403)
      ->json_is( '/error' => 'Authorization failure. Missing required permission(s).' );

    $patron->set_password({ password => $password, skip_validation => 1 });
    $userid = $patron->userid;

    $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->itemnumber )
      ->status_is( 200, 'SWAGGER3.2.2' )
      ->json_is( '' => $item->to_api, 'SWAGGER3.3.2' );

    my $non_existent_code = $item->itemnumber;
    $item->delete;

    $t->get_ok( "//$userid:$password@/api/v1/items/" . $non_existent_code )
      ->status_is(404)
      ->json_is( '/error' => 'Item not found' );

    t::lib::Mocks::mock_preference( 'item-level_itypes', 0 );

    my $biblio = $builder->build_sample_biblio;
    my $itype =
      $builder->build_object( { class => 'Koha::ItemTypes' } )->itemtype;
    $item = $builder->build_sample_item(
        { biblionumber => $biblio->biblionumber, itype => $itype } );

    $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->itemnumber )
      ->status_is( 200, 'SWAGGER3.2.2' )
      ->json_is( '/item_type_id' => $itype, 'item-level_itypes:0' )
      ->json_is( '/effective_item_type_id' => $biblio->itemtype, 'item-level_itypes:0' );

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->itemnumber )
      ->status_is( 200, 'SWAGGER3.2.2' )
      ->json_is( '/item_type_id' => $itype, 'item-level_itype:1' )
      ->json_is( '/effective_item_type_id' => $itype, 'item-level_itypes:1' );

    $schema->storage->txn_rollback;
};

subtest 'pickup_locations() tests' => sub {

    plan tests => 16;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'AllowHoldPolicyOverride', 0 );

    # Small trick to ease testing
    Koha::Libraries->search->update({ pickup_location => 0 });

    my $library_1 = $builder->build_object({ class => 'Koha::Libraries', value => { marcorgcode => 'A', pickup_location => 1 } });
    my $library_2 = $builder->build_object({ class => 'Koha::Libraries', value => { marcorgcode => 'B', pickup_location => 1 } });
    my $library_3 = $builder->build_object({ class => 'Koha::Libraries', value => { marcorgcode => 'C', pickup_location => 1 } });

    my $library_1_api = $library_1->to_api();
    my $library_2_api = $library_2->to_api();
    my $library_3_api = $library_3->to_api();

    $library_1_api->{needs_override} = Mojo::JSON->false;
    $library_2_api->{needs_override} = Mojo::JSON->false;
    $library_3_api->{needs_override} = Mojo::JSON->true;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { userid => 'tomasito', flags => 0 }
        }
    );
    my $password = 'thePassword123';
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron->borrowernumber,
                module_bit     => 6,
                code           => 'place_holds',
            },
        }
    );

    my $item = $builder->build_sample_item();

    my $item_class = Test::MockModule->new('Koha::Item');
    $item_class->mock(
        'pickup_locations',
        sub {
            my ( $self, $params ) = @_;
            my $mock_patron = $params->{patron};
            is( $mock_patron->borrowernumber,
                $patron->borrowernumber, 'Patron passed correctly' );
            return Koha::Libraries->search(
                {
                    branchcode => {
                        '-in' => [
                            $library_1->branchcode,
                            $library_2->branchcode
                        ]
                    }
                },
                {   # we make sure no surprises in the order of the result
                    order_by => { '-asc' => 'marcorgcode' }
                }
            );
        }
    );

    $t->get_ok( "//$userid:$password@/api/v1/items/"
          . $item->id
          . "/pickup_locations?patron_id=" . $patron->id )
      ->json_is( [ $library_1_api, $library_2_api ] );

    # filtering works!
    $t->get_ok( "//$userid:$password@/api/v1/items/"
          . $item->id
          . '/pickup_locations?'
          . 'patron_id=' . $patron->id . '&q={"marc_org_code": { "-like": "A%" }}' )
      ->json_is( [ $library_1_api ] );

    t::lib::Mocks::mock_preference( 'AllowHoldPolicyOverride', 1 );

    my $library_4 = $builder->build_object({ class => 'Koha::Libraries', value => { pickup_location => 0, marcorgcode => 'X' } });
    my $library_5 = $builder->build_object({ class => 'Koha::Libraries', value => { pickup_location => 1, marcorgcode => 'Y' } });

    my $library_5_api = $library_5->to_api();
    $library_5_api->{needs_override} = Mojo::JSON->true;

    $t->get_ok( "//$userid:$password@/api/v1/items/"
          . $item->id
          . "/pickup_locations?"
          . "patron_id=" . $patron->id . "&_order_by=marc_org_code" )
      ->json_is( [ $library_1_api, $library_2_api, $library_3_api, $library_5_api ] );

    subtest 'Pagination and AllowHoldPolicyOverride tests' => sub {

        plan tests => 27;

        t::lib::Mocks::mock_preference( 'AllowHoldPolicyOverride', 1 );

        $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->id . "/pickup_locations?" . "patron_id=" . $patron->id . "&_order_by=marc_org_code" . "&_per_page=1" )
          ->json_is( [$library_1_api] )
          ->header_is( 'X-Total-Count', '4', '4 is the count for libraries with pickup_location=1' )
          ->header_is( 'X-Base-Total-Count', '4', '4 is the count for libraries with pickup_location=1' )
          ->header_unlike( 'Link', qr|rel="prev"| )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=2.*|_page=2.*\&_per_page=1.*)>\; rel="next"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=1.*|_page=1.*\&_per_page=1).*>\; rel="first"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=4.*|_page=4.*\&_per_page=1).*>\; rel="last"# );

        $t->get_ok( "//$userid:$password@/api/v1/items/"
              . $item->id
              . "/pickup_locations?"
              . "patron_id="
              . $patron->id
              . "&_order_by=marc_org_code"
              . "&_per_page=1&_page=3" )    # force the needs_override=1 check
          ->json_is( [$library_3_api] )
          ->header_is( 'X-Total-Count', '4', '4 is the count for libraries with pickup_location=1' )
          ->header_is( 'X-Base-Total-Count', '4', '4 is the count for libraries with pickup_location=1' )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=2.*|_page=2.*\&_per_page=1.*)>\; rel="prev"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=4.*|_page=4.*\&_per_page=1.*)>\; rel="next"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=1.*|_page=1.*\&_per_page=1).*>\; rel="first"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=4.*|_page=4.*\&_per_page=1).*>\; rel="last"# );

        t::lib::Mocks::mock_preference( 'AllowHoldPolicyOverride', 0 );

        $t->get_ok( "//$userid:$password@/api/v1/items/" . $item->id . "/pickup_locations?" . "patron_id=" . $patron->id . "&_order_by=marc_org_code" . "&_per_page=1" )
          ->json_is( [$library_1_api] )
          ->header_is( 'X-Total-Count', '2' )
          ->header_is( 'X-Base-Total-Count', '2' )
          ->header_unlike( 'Link', qr|rel="prev"| )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=2.*|_page=2.*\&_per_page=1.*)>\; rel="next"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=1.*|_page=1.*\&_per_page=1).*>\; rel="first"# )
          ->header_like( 'Link', qr#(_per_page=1.*\&_page=2.*|_page=2.*\&_per_page=1).*>\; rel="last"# );
    };

    my $deleted_patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $deleted_patron_id = $deleted_patron->id;
    $deleted_patron->delete;

    $t->get_ok( "//$userid:$password@/api/v1/items/"
          . $item->id
          . "/pickup_locations?"
          . "patron_id=" . $deleted_patron_id )
      ->status_is( 400 )
      ->json_is( '/error' => 'Patron not found' );

    $item->delete;

    $t->get_ok( "//$userid:$password@/api/v1/items/"
          . $item->id
          . "/pickup_locations?"
          . "patron_id=" . $patron->id )
      ->status_is( 404 )
      ->json_is( '/error' => 'Item not found' );

    $schema->storage->txn_rollback;
};
