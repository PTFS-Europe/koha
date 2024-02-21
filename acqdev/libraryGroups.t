#!/usr/bin/env perl

# Copyright PTFS Europe 2024

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
# along with Koha; if not, see <http://www.gnu.olg/licenses>.

use Modern::Perl;

use Koha::Database;
use Koha::Library::Groups;

use JSON qw( decode_json );

warn "Adding group 1";
# Group 1 - two sub groups: A, B. Sub group A then has two sub groups: A1, A2
my $root_group1 = Koha::Library::Group->new(
    {
        title           => "LibGroup1",
        ft_acquisitions => 1
    }
)->store();

my $lg1groupA  = Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupA' } )->store();
my $lg1groupA1 = Koha::Library::Group->new( { parent_id => $lg1groupA->id,   title => 'LibGroup1 SubGroupA SubGroup1' } )->store();
my $lg1groupA2 = Koha::Library::Group->new( { parent_id => $lg1groupA->id,   title => 'LibGroup1 SubGroupA SubGroup2' } )->store();
my $lg1groupB  = Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupB' } )->store();

my $lg1groupA_library1 =
    Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => 'CPL' } )->store();
my $lg1groupA_library2 =
    Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => 'FPL' } )->store();
my $lg1groupB_library1 =
    Koha::Library::Group->new( { parent_id => $lg1groupB->id, branchcode => 'CPL' } )->store();
my $lg1groupA1_library1 =
    Koha::Library::Group->new( { parent_id => $lg1groupA1->id, branchcode => 'FPL' } )->store();
my $lg1groupA2_library1 =
    Koha::Library::Group->new( { parent_id => $lg1groupA2->id, branchcode => 'CPL' } )->store();

warn "Adding group 2";
# Group 2 - three sub groups: A, B, C. Sub group A then has two sub groups: A1, A2 and sub group C has two: C1, C2
my $root_group2 = Koha::Library::Group->new(
    {
        title           => "LibGroup2",
        ft_acquisitions => 1
    }
)->store();

my $lg2groupA  = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupA' } )->store();
my $lg2groupA1 = Koha::Library::Group->new( { parent_id => $lg2groupA->id,   title => 'LibGroup2 SubGroupA SubGroup1' } )->store();
my $lg2groupA2 = Koha::Library::Group->new( { parent_id => $lg2groupA->id,   title => 'LibGroup2 SubGroupA SubGroup2' } )->store();
my $lg2groupB  = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupB' } )->store();
my $lg2groupC  = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupC' } )->store();
my $lg2groupC1 = Koha::Library::Group->new( { parent_id => $lg2groupC->id,   title => 'LibGroup2 SubGroupC SubGroup1' } )->store();
my $lg2groupC2 = Koha::Library::Group->new( { parent_id => $lg2groupC->id,   title => 'LibGroup2 SubGroupC SubGroup2' } )->store();

my $lg2groupA_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => 'CPL' } )->store();
my $lg2groupA_library2 =
    Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => 'MPL' } )->store();
my $lg2groupB_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupB->id, branchcode => 'CPL' } )->store();
my $lg2groupC_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'CPL' } )->store();
my $lg2groupC_library2 =
    Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'MPL' } )->store();
my $lg2groupC_library3 =
    Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'TPL' } )->store();
my $lg2groupA1_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupA1->id, branchcode => 'MPL' } )->store();
my $lg2groupA2_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupA2->id, branchcode => 'CPL' } )->store();
my $lg2groupC1_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupC1->id, branchcode => 'MPL' } )->store();
my $lg2groupC2_library1 =
    Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => 'CPL' } )->store();
my $lg2groupC2_library2 =
    Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => 'TPL' } )->store();

warn "Adding group 3";
# Group 3 - This group does not contain 'CPL' to check that it is being missed in the filtering
my $root_group3 = Koha::Library::Group->new(
    {
        title           => "LibGroup3",
        ft_acquisitions => 1
    }
)->store();

my $lg3groupA = Koha::Library::Group->new( { parent_id => $root_group3->id, title => 'LibGroup3 SubGroupA' } )->store();
my $lg3groupA_library1 =
    Koha::Library::Group->new( { parent_id => $lg3groupA->id, branchcode => 'FFL' } )->store();

warn "Adding group 4";
# Group 3 - This group does not apply to the acquisitions module and therefore should never appear
my $root_group4 = Koha::Library::Group->new(
    {
        title           => "LibGroup4",
        ft_acquisitions => 0
    }
)->store();

my $lg4groupA = Koha::Library::Group->new( { parent_id => $root_group4->id, title => 'LibGroup4 SubGroupA' } )->store();
my $lg4groupA_library1 =
    Koha::Library::Group->new( { parent_id => $lg4groupA->id, branchcode => 'CPL' } )->store();

warn "All library groups added";
