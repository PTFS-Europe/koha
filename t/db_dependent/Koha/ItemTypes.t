#!/usr/bin/perl
#
# Copyright 2014 Catalyst IT
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

use Data::Dumper;
use Test::More tests => 14;

use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Calendar qw( new );
use Koha::Biblioitems;
use Koha::Libraries;
use Koha::Database;
use Koha::DateUtils qw(dt_from_string);;
use Koha::Items;

BEGIN {
    use_ok('Koha::ItemType');
    use_ok('Koha::ItemTypes');
}

my $database = Koha::Database->new();
my $schema   = $database->schema();
$schema->txn_begin;

my $builder     = t::lib::TestBuilder->new;
my $initial_count = Koha::ItemTypes->search->count;

my $parent1 = $builder->build_object({ class => 'Koha::ItemTypes', value => { description => 'description' } });
my $child1  = $builder->build_object({
        class => 'Koha::ItemTypes',
        value => {
            parent_type => $parent1->itemtype,
            description => 'description',
        }
    });
my $child2  = $builder->build_object({
        class => 'Koha::ItemTypes',
        value => {
            parent_type => $parent1->itemtype,
            description => 'description',
        }
    });
my $child3  = $builder->build_object({
        class => 'Koha::ItemTypes',
        value => {
            parent_type => $parent1->itemtype,
            description => 'description',
        }
    });

my $type = Koha::ItemTypes->find($child1->itemtype);
ok( defined($type), 'first result' );
is_deeply( $type->unblessed, $child1->unblessed, "We got back the same object" );
is_deeply( $type->parent->unblessed, $parent1->unblessed, 'The parent method returns the correct object');

$type = Koha::ItemTypes->find($child2->itemtype);
ok( defined($type), 'second result' );
is_deeply( $type->unblessed, $child2->unblessed, "We got back the same object" );

t::lib::Mocks::mock_preference('language', 'en');
t::lib::Mocks::mock_preference('OPACLanguages', 'en');
my $itemtypes = Koha::ItemTypes->search;
is( $itemtypes->count, $initial_count + 4, 'We added 4 item types' );

my $children = $parent1->children;
is ($children->count, 3, 'parent type has 3 children');

my $item_type = $builder->build_object({ class => 'Koha::ItemTypes' });

is( $item_type->can_be_deleted, 1, 'An item type that is not used can be deleted');

my $item = $builder->build_sample_item({ itype => $item_type->itemtype });
is( $item_type->can_be_deleted, 0, 'An item type that is used by an item cannot be deleted' );
$item->delete;

my $biblio = $builder->build_sample_biblio({ itemtype => $item_type->itemtype });
is ( $item_type->can_be_deleted, 0, 'An item type that is used by an item and a biblioitem cannot be deleted' );
$biblio->delete;

is ( $item_type->can_be_deleted, 1, 'The item type that was being used by the removed item and biblioitem can now be deleted' );

$schema->txn_rollback;
