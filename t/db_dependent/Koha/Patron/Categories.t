#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
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

use Test::More tests => 10;

use C4::Context;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Patron::Category;
use Koha::Patron::Categories;
use t::lib::Dates;
use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $library_1 = $builder->build_object({ class => 'Koha::Libraries', });
my $library_2 = $builder->build_object({ class => 'Koha::Libraries', });
my $nb_of_categories = Koha::Patron::Categories->search->count;
my $new_category_1 = Koha::Patron::Category->new({
    categorycode => 'mycatcodeX',
    category_type => 'A',
    description  => 'mycatdescX',
})->store;
$new_category_1->replace_library_limits( [ $library_1->branchcode, $library_2->branchcode ] );
my $new_category_2 = Koha::Patron::Category->new({
    categorycode => 'mycatcodeY',
    category_type => 'S',
    description  => 'mycatdescY',
    checkprevcheckout => undef,
})->store;

is( Koha::Patron::Categories->search->count, $nb_of_categories + 2, 'The 2 patron categories should have been added' );

my $retrieved_category_1 = Koha::Patron::Categories->find( $new_category_1->categorycode );
is( $retrieved_category_1->categorycode, $new_category_1->categorycode, 'Find a patron category by categorycode should return the correct category' );
is_deeply( [ sort $retrieved_category_1->library_limits->get_column('branchcode') ], [ sort $library_1->branchcode, $library_2->branchcode ], 'The branch limitation should have been stored and retrieved' );
is_deeply( $retrieved_category_1->default_messaging, [], 'By default there is not messaging option' );

my $retrieved_category_2 = Koha::Patron::Categories->find( $new_category_2->categorycode );
is( $retrieved_category_1->checkprevcheckout, 'inherit', 'Koha::Patron::Category->store should default checkprevcheckout to inherit' );
is( $retrieved_category_2->checkprevcheckout, 'inherit', 'Koha::Patron::Category->store should default checkprevcheckout to inherit' );

subtest 'get_expiry_date' => sub {
    plan tests => 7;
    my $next_month = dt_from_string->add( months => 1 );
    my $next_year = dt_from_string->add( months => 12 );
    my $yesterday = dt_from_string->add( days => -1 );
    my $category = Koha::Patron::Category->new({
        categorycode => 'mycat',
        category_type => 'A',
        description  => 'mycatdesc',
        enrolmentperiod => undef,
        enrolmentperioddate => $next_month,
    })->store;
    is( $category->get_expiry_date, $next_month, 'Without enrolmentperiod and parameter, ->get_expiry_date should return enrolmentperioddate' );
    is( $category->get_expiry_date( $next_year ), $next_month, 'Without enrolmentperiod, ->get_expiry_date should return enrolmentperiodadate even if a parameter is given' );

    my $dt          = dt_from_string;
    my $original_dt = $dt->clone;
    $category->get_expiry_date($dt);
    is(
        t::lib::Dates::compare( $dt, $original_dt ), 0,
        'Without enrolment period, DateTime object passed as a parameter should not be modified when ->get_expiry_date is called'
    );

    $category->enrolmentperiod( 12 )->store;
    is( t::lib::Dates::compare($category->get_expiry_date, $next_year), 0, 'With enrolmentperiod defined and no parameter, ->get_expiry_date should return today + enrolmentperiod' );
    is( t::lib::Dates::compare($category->get_expiry_date( $yesterday ), $next_year->clone->add( days => -1 )), 0, 'With enrolmentperiod defined and a date given in parameter, ->get_expiry_date should take this date + enrolmentperiod' );

    $dt          = dt_from_string;
    $original_dt = $dt->clone;
    $category->get_expiry_date($dt);
    is(
        t::lib::Dates::compare( $dt, $original_dt ), 0,
        'With enrolment period defined, DateTime object passed as a parameter should not be modified when ->get_expiry_date is called'
    );

    my $hardcoded_date = '2000-01-31';
    is( t::lib::Dates::compare($category->get_expiry_date( $hardcoded_date ), dt_from_string( $hardcoded_date )->add( months => 12 )), 0, 'get_expiry_date accepts strings as well'  );

    $category->delete;
};

subtest 'BlockExpiredPatronOpacActions' => sub {
    plan tests => 4;
    t::lib::Mocks::mock_preference('BlockExpiredPatronOpacActions', 'hold,ill_request');
    my $category = Koha::Patron::Category->new({
        categorycode => 'ya_cat',
        category_type => 'A',
        description  => 'yacatdesc',
        enrolmentperiod => undef,
        BlockExpiredPatronOpacActions => 'follow_syspref_BlockExpiredPatronOpacActions',
    })->store;
    is( $category->effective_BlockExpiredPatronOpacActions_contains('hold'), 1 );
    is( $category->effective_BlockExpiredPatronOpacActions_contains('ill_request'), 1 );
    is( $category->effective_BlockExpiredPatronOpacActions_contains('renew'), undef );
    $category->BlockExpiredPatronOpacActions('renew')->store;
    is( $category->effective_BlockExpiredPatronOpacActions_contains('renew'), 1 );
    $category->delete;
};

$retrieved_category_1->delete;
is( Koha::Patron::Categories->search->count, $nb_of_categories + 1, 'Delete should have deleted the patron category' );

my $new_category_4 = Koha::Patron::Category->new(
    {   categorycode => 'mycatcodeW',
        category_type => 'A',
        description  => 'mycatdescW',
        upperagelimit => '',
        dateofbirthrequired => '',
    }
)->store;
is( Koha::Patron::Categories->search->count, $nb_of_categories + 2, 'upperagelimit and dateofbirthrequired should have a default value if empty string is passed' );

$schema->storage->txn_rollback;

