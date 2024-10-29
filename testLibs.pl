use Modern::Perl;

use t::lib::TestBuilder;

use Koha::Acquisition::Bookseller;

create_library_groups();
create_vendors();

sub create_library_groups {
    warn "Adding group 1";

    # Group 1 - two sub groups: A, B. Sub group A then has two sub groups: A1, A2
    my $root_group1 = Koha::Library::Group->new(
        {
            title           => "LibGroup1",
            ft_acquisitions => 1
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

    my $lg3groupA =
        Koha::Library::Group->new( { parent_id => $root_group3->id, title => 'LibGroup3 SubGroupA' } )->store();
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

    my $lg4groupA =
        Koha::Library::Group->new( { parent_id => $root_group4->id, title => 'LibGroup4 SubGroupA' } )->store();
    my $lg4groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg4groupA->id, branchcode => 'CPL' } )->store();

    warn "All library groups added";

}


sub create_vendors {
    my $vendor1 = Koha::Acquisition::Bookseller->new( { name => 'Vendor 1', lib_group_visibility => '|1|11|' } )->store();
    my $vendor2 = Koha::Acquisition::Bookseller->new( { name => 'Vendor 2', lib_group_visibility => '|1|11|' } )->store();
    my $vendor3 = Koha::Acquisition::Bookseller->new( { name => 'Vendor 3', lib_group_visibility => '|1|' } )->store();
}