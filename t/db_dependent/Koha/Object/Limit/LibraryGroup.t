#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright PTFS Europe 2024
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
use Test::More tests => 2;
use t::lib::TestBuilder;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->schema;

subtest 'set_lib_group_visibility' => sub {
    plan tests => 3;

    $schema->txn_begin;

    my $root_group1 = Koha::Library::Group->new(
        {
            title => "LibGroup1",
        }
    )->store();

    my $lg1groupA =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupA' } )->store();
    my $lg1groupA1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, title => 'LibGroup1 SubGroupA SubGroup1' } )->store();
    my $lg1groupB =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupB' } )->store();

    my $vendor = $builder->build_object(
        { class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => undef } } );

    # Pass in an array
    my @vendor_lib_groups = ( $lg1groupA->id, $lg1groupB->id );
    $vendor->set_lib_group_visibility( { new_visibility => \@vendor_lib_groups } );
    is(
        $vendor->lib_group_visibility, "|" . join( '|', @vendor_lib_groups ) . "|",
        'Got correct lib group visibility'
    );

    # Update with another array
    @vendor_lib_groups = ( $lg1groupA1->id, $lg1groupB->id );
    $vendor->set_lib_group_visibility( { new_visibility => \@vendor_lib_groups } );
    is(
        $vendor->lib_group_visibility, "|" . join( '|', @vendor_lib_groups ) . "|",
        'Got correct lib group visibility'
    );

    # Use the call in the object's "store" method
    $vendor->lib_group_visibility( "|" . $lg1groupA->id . "|" )->store;
    is(
        $vendor->lib_group_visibility, "|" . $lg1groupA->id . "|",
        'Lib group visibility has been overridden correctly'
    );

    $schema->txn_rollback;
};

subtest 'lib_group_limits' => sub {
    plan tests => 2;

    $schema->txn_begin;

    my $root_group1 = Koha::Library::Group->new(
        {
            title => "LibGroup1",
        }
    )->store();

    my $lg1groupA =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupA' } )->store();
    my $lg1groupB =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupB' } )->store();

    my $vendor = $builder->build_object(
        { class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => undef } } );

    my @vendor_lib_groups = ( $lg1groupA->id, $lg1groupB->id );
    $vendor->set_lib_group_visibility( { new_visibility => \@vendor_lib_groups } );

    my $lib_groups = $vendor->lib_group_limits;

    is( scalar(@$lib_groups), 2, 'Got correct number of lib groups' );
    my @ids = sort { $a <=> $b } map { $_->id } @$lib_groups;
    is( join( '|', @ids ), join( '|', @vendor_lib_groups ), 'Got correct lib groups' );

    $schema->txn_rollback;
};
