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

use Test::More tests => 7;

use C4::Biblio;
use C4::Context;
use C4::Items;

use Koha::Biblios;
use Koha::Item::Transfer::Limits;
use Koha::Items;
use Koha::Library;
use Koha::Libraries;
use Koha::Database;

use t::lib::Mocks;
use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $nb_of_libraries = Koha::Libraries->search->count;
my $new_library_1 = Koha::Library->new({
    branchcode => 'my_bc_1',
    branchname => 'my_branchname_1',
    branchnotes => 'my_branchnotes_1',
    marcorgcode => 'US-MyLib',
})->store;
my $new_library_2 = Koha::Library->new({
    branchcode => 'my_bc_2',
    branchname => 'my_branchname_2',
    branchnotes => 'my_branchnotes_2',
})->store;

is( Koha::Libraries->search->count,         $nb_of_libraries + 2,  'The 2 libraries should have been added' );

my $retrieved_library_1 = Koha::Libraries->find( $new_library_1->branchcode );
is( $retrieved_library_1->branchname, $new_library_1->branchname, 'Find a library by branchcode should return the correct library' );

$retrieved_library_1->delete;
is( Koha::Libraries->search->count, $nb_of_libraries + 1, 'Delete should have deleted the library' );

# Stockrotation relationship testing

my $new_library_sr = $builder->build({ source => 'Branch' });

$builder->build({
    source => 'Stockrotationstage',
    value  => { branchcode_id => $new_library_sr->{branchcode} },
});
$builder->build({
    source => 'Stockrotationstage',
    value  => { branchcode_id => $new_library_sr->{branchcode} },
});
$builder->build({
    source => 'Stockrotationstage',
    value  => { branchcode_id => $new_library_sr->{branchcode} },
});

my $srstages = Koha::Libraries->find($new_library_sr->{branchcode})
    ->stockrotationstages;
is( $srstages->count, 3, 'Correctly fetched stockrotationstages associated with this branch');

isa_ok( $srstages->next, 'Koha::StockRotationStage', "Relationship correctly creates Koha::Objects." );

subtest 'pickup_locations' => sub {
    plan tests => 2;

    my $from = Koha::Library->new({
        branchcode => 'zzzfrom',
        branchname => 'zzzfrom',
        branchnotes => 'zzzfrom',
    })->store;
    my $to = Koha::Library->new({
        branchcode => 'zzzto',
        branchname => 'zzzto',
        branchnotes => 'zzzto',
    })->store;

    my ($bibnum, $title, $bibitemnum) = create_helper_biblio('DUMMY');
    # Create item instance for testing.
    my ($item_bibnum1, $item_bibitemnum1, $itemnumber1)
    = AddItem({ homebranch => $from->branchcode,
                holdingbranch => $from->branchcode } , $bibnum);
    my ($item_bibnum2, $item_bibitemnum2, $itemnumber2)
    = AddItem({ homebranch => $from->branchcode,
                holdingbranch => $from->branchcode } , $bibnum);
    my ($item_bibnum3, $item_bibitemnum3, $itemnumber3)
    = AddItem({ homebranch => $from->branchcode,
                holdingbranch => $from->branchcode } , $bibnum);
    my $item1 = Koha::Items->find($itemnumber1);
    my $item2 = Koha::Items->find($itemnumber2);
    my $item3 = Koha::Items->find($itemnumber3);
    my $biblio = Koha::Biblios->find($bibnum);
    my $itemtype = $biblio->itemtype;

    subtest 'UseBranchTransferLimits = OFF' => sub {
        plan tests => 5;

        t::lib::Mocks::mock_preference('UseBranchTransferLimits', 0);
        t::lib::Mocks::mock_preference('BranchTransferLimitsType', 'itemtype');
        t::lib::Mocks::mock_preference('item-level_itypes', 1);
        Koha::Item::Transfer::Limits->delete;
        Koha::Item::Transfer::Limit->new({
            fromBranch => $from->branchcode,
            toBranch => $to->branchcode,
            itemtype => $biblio->itemtype,
        })->store;
        my $total_pickup = Koha::Libraries->search({
            pickup_location => 1
        })->count;
        my $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
        is(C4::Context->preference('UseBranchTransferLimits'), 0, 'Given system '
           .'preference UseBranchTransferLimits is switched OFF,');
        is(@{$pickup}, $total_pickup, 'Then the total number of pickup locations '
           .'equal number of libraries with pickup_location => 1');

        t::lib::Mocks::mock_preference('BranchTransferLimitsType', 'itemtype');
        t::lib::Mocks::mock_preference('item-level_itypes', 1);
        $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
        is(@{$pickup}, $total_pickup, '...when '
           .'BranchTransferLimitsType = itemtype and item-level_itypes = 1');
        t::lib::Mocks::mock_preference('item-level_itypes', 0);
        $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
        is(@{$pickup}, $total_pickup, '...as well as when '
           .'BranchTransferLimitsType = itemtype and item-level_itypes = 0');
        t::lib::Mocks::mock_preference('BranchTransferLimitsType', 'ccode');
        $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
        is(@{$pickup}, $total_pickup, '...as well as when '
           .'BranchTransferLimitsType = ccode');
        t::lib::Mocks::mock_preference('item-level_itypes', 1);
    };

    subtest 'UseBranchTransferLimits = ON' => sub {
        plan tests => 4;
        t::lib::Mocks::mock_preference('UseBranchTransferLimits', 1);

        is(C4::Context->preference('UseBranchTransferLimits'), 1, 'Given system '
           .'preference UseBranchTransferLimits is switched ON,');

        subtest 'Given BranchTransferLimitsType = itemtype and '
               .'item-level_itypes = ON' => sub {
            plan tests => 11;

            t::lib::Mocks::mock_preference('BranchTransferLimitsType','itemtype');
            t::lib::Mocks::mock_preference('item-level_itypes', 1);
            Koha::Item::Transfer::Limits->delete;
            my $limit = Koha::Item::Transfer::Limit->new({
                fromBranch => $from->branchcode,
                toBranch => $to->branchcode,
                itemtype => $item1->effective_itemtype,
            })->store;
            ok($item1->effective_itemtype eq $item2->effective_itemtype
               && $item1->effective_itemtype eq $item3->effective_itemtype,
               'Given all items of a biblio have same the itemtype,');
            is($limit->itemtype, $item1->effective_itemtype, 'and given there '
               .'is an existing transfer limit for that itemtype,');
            my $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            my $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'Then the to-library of which the limit applies for, '
               .'is not included in the list of pickup libraries.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'The same applies when asking pickup locations of '
               .'a single item.');
            my $others = Koha::Libraries->search({
                pickup_location => 1,
                branchcode => { 'not in' => [$limit->toBranch] }})->count;
            is(@{$pickup}, $others, 'However, the number of other pickup '
               .'libraries is correct.');
            $item2->itype('BK')->store;
            ok($item1->effective_itemtype ne $item2->effective_itemtype,
               'Given one of the item in this biblio has a different itemtype,');
            is(Koha::Item::Transfer::Limits->search({
                itemtype => $item2->effective_itemtype })->count, 0, 'and it is'
               .' not restricted by transfer limits,');
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Then the to-library of which the limit applies for, '
               .'is included in the list of pickup libraries.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item2 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'The same applies when asking pickup locations of '
               .'a that particular item.');
            Koha::Item::Transfer::Limits->delete;
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Given we deleted transfer limit, the previously '
               .'transfer-limited library is included in the list.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'The same applies when asking pickup locations of '
               .'a single item.');
        };

        subtest 'Given BranchTransferLimitsType = itemtype and '
               .'item-level_itypes = OFF' => sub {
            plan tests => 9;

            t::lib::Mocks::mock_preference('BranchTransferLimitsType','itemtype');
            t::lib::Mocks::mock_preference('item-level_itypes', 0);
            $biblio->biblioitem->itemtype('BK')->store;
            Koha::Item::Transfer::Limits->delete;
            my $limit = Koha::Item::Transfer::Limit->new({
                fromBranch => $from->branchcode,
                toBranch => $to->branchcode,
                itemtype => $item1->effective_itemtype,
            })->store;

            ok($item1->effective_itemtype eq 'BK',
               'Given items use biblio-level itemtype,');
            is($limit->itemtype, $item1->effective_itemtype, 'and given there '
               .'is an existing transfer limit for that itemtype,');
            my $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            my $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'Then the to-library of which the limit applies for, '
               .'is not included in the list of pickup libraries.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'The same applies when asking pickup locations of '
               .'a single item.');
            my $others = Koha::Libraries->search({
                pickup_location => 1,
                branchcode => { 'not in' => [$limit->toBranch] }})->count;
            is(@{$pickup}, $others, 'However, the number of other pickup '
               .'libraries is correct.');
            Koha::Item::Transfer::Limits->delete;
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Given we deleted transfer limit, the previously '
               .'transfer-limited library is included in the list.');
            $limit = Koha::Item::Transfer::Limit->new({
                fromBranch => $from->branchcode,
                toBranch => $to->branchcode,
                itemtype => $item1->itype,
            })->store;
            ok($item1->itype ne $item1->effective_itemtype
               && $limit->itemtype eq $item1->itype, 'Given we have added a limit'
               .' matching ITEM-level itemtype,');
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Then the limited branch is still included as a pickup'
               .' library.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'The same applies when asking pickup locations of '
               .'a single item.');
        };

        subtest 'Given BranchTransferLimitsType = ccode' => sub {
            plan tests => 10;

            t::lib::Mocks::mock_preference('BranchTransferLimitsType', 'ccode');
            $item1->ccode('hi')->store;
            $item2->ccode('hi')->store;
            $item3->ccode('hi')->store;
            Koha::Item::Transfer::Limits->delete;
            my $limit = Koha::Item::Transfer::Limit->new({
                fromBranch => $from->branchcode,
                toBranch => $to->branchcode,
                ccode => $item1->ccode,
            })->store;

            is($limit->ccode, $item1->ccode, 'Given there '
               .'is an existing transfer limit for that ccode,');
            my $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            my $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'Then the to-library of which the limit applies for, '
               .'is not included in the list of pickup libraries.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 0, 'The same applies when asking pickup locations of '
               .'a single item.');
            my $others = Koha::Libraries->search({
                pickup_location => 1,
                branchcode => { 'not in' => [$limit->toBranch] }})->count;
            is(@{$pickup}, $others, 'However, the number of other pickup '
               .'libraries is correct.');
            $item3->ccode('yo')->store;
            ok($item1->ccode ne $item3->ccode,
               'Given one of the item in this biblio has a different ccode,');
            is(Koha::Item::Transfer::Limits->search({
                ccode => $item3->ccode })->count, 0, 'and it is'
               .' not restricted by transfer limits,');
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Then the to-library of which the limit applies for, '
               .'is included in the list of pickup libraries.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item3 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'The same applies when asking pickup locations of '
               .'a that particular item.');
            Koha::Item::Transfer::Limits->delete;
            $pickup = Koha::Libraries->pickup_locations({ biblio => $bibnum });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'Given we deleted transfer limit, the previously '
               .'transfer-limited library is included in the list.');
            $pickup = Koha::Libraries->pickup_locations({ item => $item1 });
            $found = 0;
            foreach my $lib (@{$pickup}) {
                if ($lib->{'branchcode'} eq $limit->toBranch) {
                    $found = 1;
                }
            }
            is($found, 1, 'The same applies when asking pickup locations of '
               .'a single item.');
        };
    };
};

sub create_helper_biblio {
    my $itemtype = shift;
    my ($bibnum, $title, $bibitemnum);
    my $bib = MARC::Record->new();
    $title = 'Silence in the library';
    $bib->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Moffat, Steven'),
        MARC::Field->new('245', ' ', ' ', a => $title),
        MARC::Field->new('942', ' ', ' ', c => $itemtype),
    );
    return ($bibnum, $title, $bibitemnum) = AddBiblio($bib, '');
}

$schema->storage->txn_rollback;

subtest '->get_effective_marcorgcode' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $library_1 = $builder->build_object({ class => 'Koha::Libraries',
                                             value => { marcorgcode => 'US-MyLib' } });
    my $library_2 = $builder->build_object({ class => 'Koha::Libraries',
                                             value => { marcorgcode => undef } });

    t::lib::Mocks::mock_preference('MARCOrgCode', 'US-Default');

    is( $library_1->get_effective_marcorgcode, 'US-MyLib',
       'If defined, use library\'s own marc org code');
    is( $library_2->get_effective_marcorgcode, 'US-Default',
       'If not defined library\' marc org code, use the one from system preferences');

    t::lib::Mocks::mock_preference('MARCOrgCode', 'Blah');
    is( $library_2->get_effective_marcorgcode, 'Blah',
       'Fallback is always MARCOrgCode syspref');

    $library_2->marcorgcode('ThisIsACode')->store();
    is( $library_2->get_effective_marcorgcode, 'ThisIsACode',
       'Pick library_2 code');

    $schema->storage->txn_rollback;
};
