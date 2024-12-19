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
use Test::More tests => 1;
use t::lib::TestBuilder;
use t::lib::Mocks;

my $builder = t::lib::TestBuilder->new;
my $schema  = Koha::Database->schema;

subtest 'define_library_group_limits' => sub {
    plan tests => 8;

    $schema->txn_begin;

    Koha::Acquisition::Baskets->delete;
    Koha::Acquisition::Booksellers->delete;

    my $library1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library2 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library3 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library4 = $builder->build_object( { class => 'Koha::Libraries' } );

    # Group 1 - two sub groups: A, B. Sub group A then has two sub groups: A1, A2
    my $root_group1 = Koha::Library::Group->new(
        {
            title => "LibGroup1",
        }
    )->store();

    my $lg1groupA =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupA' } )->store();
    my $lg1groupA1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, title => 'LibGroup1 SubGroupA SubGroup1' } )->store();
    my $lg1groupA2 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, title => 'LibGroup1 SubGroupA SubGroup2' } )->store();
    my $lg1groupB =
        Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupB' } )->store();

    my $lg1groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => $library1->branchcode } )->store();
    my $lg1groupA_library2 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => $library2->branchcode } )->store();
    my $lg1groupB_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupB->id, branchcode => $library1->branchcode } )->store();
    my $lg1groupA1_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA1->id, branchcode => $library2->branchcode } )->store();
    my $lg1groupA2_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA2->id, branchcode => $library1->branchcode } )->store();

    # Group 2 - three sub groups: A, B, C. Sub group A then has two sub groups: A1, A2 and sub group C has two: C1, C2
    my $root_group2 = Koha::Library::Group->new(
        {
            title => "LibGroup2",
        }
    )->store();

    my $lg2groupA =
        Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupA' } )->store();
    my $lg2groupA1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, title => 'LibGroup2 SubGroupA SubGroup1' } )->store();
    my $lg2groupA2 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, title => 'LibGroup2 SubGroupA SubGroup2' } )->store();
    my $lg2groupB =
        Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupB' } )->store();
    my $lg2groupC =
        Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupC' } )->store();
    my $lg2groupC1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, title => 'LibGroup2 SubGroupC SubGroup1' } )->store();
    my $lg2groupC2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, title => 'LibGroup2 SubGroupC SubGroup2' } )->store();

    my $lg2groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => $library1->branchcode } )->store();
    my $lg2groupA_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => $library3->branchcode } )->store();
    my $lg2groupB_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupB->id, branchcode => $library1->branchcode } )->store();
    my $lg2groupC_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => $library1->branchcode } )->store();
    my $lg2groupC_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => $library3->branchcode } )->store();
    my $lg2groupC_library3 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => $library4->branchcode } )->store();
    my $lg2groupA1_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA1->id, branchcode => $library3->branchcode } )->store();
    my $lg2groupA2_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA2->id, branchcode => $library1->branchcode } )->store();
    my $lg2groupC1_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC1->id, branchcode => $library3->branchcode } )->store();
    my $lg2groupC2_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => $library1->branchcode } )->store();
    my $lg2groupC2_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => $library4->branchcode } )->store();

    my $vendor1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => "|" . $root_group1->id . "|" }
        }
    );
    my $vendor2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => "|" . $root_group2->id . "|" }
        }
    );

    t::lib::Mocks::mock_userenv( { branchcode => $library1->branchcode } );
    my $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is( scalar(@$vendors), 2, "Two vendors returned" );

    t::lib::Mocks::mock_userenv( { branchcode => $library2->branchcode } );
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is( scalar(@$vendors), 1, "One vendor returned as library2 is not in root_group2" );

    my $vendor3 = $builder->build_object(
        { class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => "|" . $lg2groupA->id . "|" } }
    );
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is( scalar(@$vendors), 1, "Still only one vendor returned as library2 is not in root_group2 or lg2groupA" );

    t::lib::Mocks::mock_userenv( { branchcode => $library3->branchcode } );
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is( scalar(@$vendors), 2, "Two vendors now returned as library3 is in lg2groupA and root_group2" );

    my $vendor4 = $builder->build_object(
        { class => 'Koha::Acquisition::Booksellers', value => { lib_group_visibility => "|" . $lg2groupB->id . "|" } }
    );
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is(
        scalar(@$vendors), 2,
        "Still two vendors returned as library3 is in lg2groupA and root_group2 but not lg2groupB"
    );

    t::lib::Mocks::mock_userenv( { branchcode => $library4->branchcode } );
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is(
        scalar(@$vendors), 1,
        "One vendor returned as library2 is only in root_group2 but not the previously assigned sub groups"
    );
    $vendor2->lib_group_visibility( "|" . $root_group1->id . "|" )->store;
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is( scalar(@$vendors), 0, "No vendors returned as none are visible to this branch code" );

    $vendor2->lib_group_visibility(undef)->store;
    $vendors = Koha::Acquisition::Booksellers->search()->as_list;
    is(
        scalar(@$vendors), 1,
        "One vendor returned as its lib_group_visibility is now undefined and so is visible to all"
    );

    $schema->txn_rollback;
};
