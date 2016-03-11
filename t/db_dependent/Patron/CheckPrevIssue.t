#!/usr/bin/perl
use Modern::Perl;

use C4::Members;
use C4::Circulation;
use Koha::Categories;
use Koha::Category;
use Koha::Database;
use Koha::Patrons;
use Koha::Patron;
use Koha::Items;
use Koha::Item;

use Test::More tests => 55;

use_ok('Koha::Patron::CheckPrevIssue');

use Koha::Patron::CheckPrevIssue qw( WantsCheckPrevIssue CheckPrevIssue );

use t::lib::TestBuilder;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;
my $yesCatCode = $builder->build({
    source => 'Category',
    value => {
        categorycode => 'yesCat',
        checkprevissue => 'yes',
    },
});

my $noCatCode = $builder->build({
    source => 'Category',
    value => {
        categorycode => 'noCat',
        checkprevissue => 'no',
    },
});

my $inheritCatCode = $builder->build({
    source => 'Category',
    value => {
        categorycode => 'inheritCat',
        checkprevissue => 'inherit',
    },
});

# WantsCheckPrevIssue

# We expect the following result matrix:
#
# (1/0 indicates the return value of WantsCheckPrevIssue; i.e. 1 says we
# should check whether the item was previously issued)
#
# | System Preference | hardyes                           | softyes                           | softno                            | hardno                            |
# |-------------------+-----------------------------------+-----------------------------------+-----------------------------------+-----------------------------------|
# | Category Setting  | yes       | no        | inherit   | yes       | no        | inherit   | yes       | no        | inherit   | yes       | no        | inherit   |
# |-------------------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------|
# | Patron Setting    | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i | y | n | i |
# |-------------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
# | Expected Result   | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

my $mappings = [
    {
        syspref    => 'hardyes',
        categories => [
            {
                setting   => 'yes',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 1},
                    {setting => 'inherit', result => 1},
                ],
            },
            {
                setting   => 'no',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 1},
                    {setting => 'inherit', result => 1},
                ],
            },
            {
                setting   => 'inherit',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 1},
                    {setting => 'inherit', result => 1},
                ],
            },
        ],
    },
    {
        syspref    => 'softyes',
        categories => [
            {
                setting  => 'yes',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 1},
                ],
            },
            {
                setting  => 'no',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
            {
                setting  => 'inherit',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 1},
                ],
            },
        ],
    },
    {
        syspref    => 'softno',
        categories => [
            {
                setting  => 'yes',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 1},
                ],
            },
            {
                setting  => 'no',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
            {
                setting  => 'inherit',
                borrowers => [
                    {setting => 'yes',     result => 1},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
        ],
    },
    {
        syspref    => 'hardno',
        categories => [
            {
                setting  => 'yes',
                borrowers => [
                    {setting => 'yes',     result => 0},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
            {
                setting  => 'no',
                borrowers => [
                    {setting => 'yes',     result => 0},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
            {
                setting  => 'inherit',
                borrowers => [
                    {setting => 'yes',     result => 0},
                    {setting => 'no',      result => 0},
                    {setting => 'inherit', result => 0},
                ],
            },
        ],
    },
];

map {
    my $syspref = $_->{syspref};
    map {
        my $code = $_->{setting} . 'Cat';
        map {
            my $brw = {
                checkprevissue => $_->{setting},
                categorycode => $code,
            };
            is(
                WantsCheckPrevIssue($brw, $syspref), $_->{result},
                "Predicate with syspref " . $syspref . ", cat " . $code
                    . ", brw " . $_->{setting}
              );
        } @{$_->{borrowers}};
    } @{$_->{categories}};
} @{$mappings};

# CheckPrevIssue

# We want to test:
# - DESCRIPTION [RETURNVALUE (0/1)]
## PreIssue (sanity checks)
# - Item, patron [0]
# - Diff item, same bib, same patron [0]
# - Diff item, diff bib, same patron [0]
# - Same item, diff patron [0]
# - Diff item, same bib, diff patron [0]
# - Diff item, diff bib, diff patron [0]
## PostIssue
# - Same item, same patron [1]
# - Diff item, same bib, same patron [1]
# - Diff item, diff bib, same patron [0]
# - Same item, diff patron [0]
# - Diff item, same bib, diff patron [0]
# - Diff item, diff bib, diff patron [0]
## PostReturn
# - Same item, same patron [1]
# - Diff item, same bib, same patron [1]
# - Diff item, diff bib, same patron [0]
# - Same item, diff patron [0]
# - Diff item, same bib, diff patron [0]
# - Diff item, diff bib, diff patron [0]

# Requirements:
# $patron, $different_patron, $items (same bib number), $different_item
my $patron = $builder->build({source => 'Borrower'});
my $patron_d = $builder->build({source => 'Borrower'});
my $item_1 = $builder->build({source => 'Item'});
my $item_2 = $builder->build({
    source => 'Item',
    value => { biblionumber => $item_1->{biblionumber} },
});
my $item_d = $builder->build({source => 'Item'});

## Testing Sub
sub test_it {
    my ($mapping, $stage) = @_;
    map {
        is(CheckPrevIssue(
            $_->{patron}, $_->{item}), $_->{result}, $stage . ": " . $_->{msg}
        );
    } @{$mapping};
};

## Initial Mappings
my $cpvmappings = [
    {
        msg => "Item, patron [0]",
        item => $item_1,
        patron => $patron,
        result => 0,
    },
    {
        msg => "Diff item, same bib, same patron [0]",
        item => $item_2,
        patron => $patron,
        result => 0,
    },
    {
        msg => "Diff item, diff bib, same patron [0]",
        item => $item_d,
        patron => $patron,
        result => 0,
    },
    {
        msg => "Same item, diff patron [0]",
        item => $item_1,
        patron => $patron_d,
        result => 0,
    },
    {
        msg => "Diff item, same bib, diff patron [0]",
        item => $item_2,
        patron => $patron_d,
        result => 0,
    },
    {
        msg => "Diff item, diff bib, diff patron [0]",
        item => $item_d,
        patron => $patron_d,
        result => 0,
    },
];

test_it($cpvmappings, "PreIssue");

# Issue item_1 to $patron:
my @USERENV = (
    $patron->{borrowernumber}, 'test', 'MASTERTEST', 'firstname', 'CPL',
    'CPL', 'email@example.org'
);
C4::Context->_new_userenv('DUMMY_SESSION_ID');
C4::Context->set_userenv(@USERENV);
BAIL_OUT("No userenv") unless C4::Context->userenv;

my $borrower = GetMember(%{{borrowernumber => $patron->{borrowernumber}}});

BAIL_OUT("Issue failed") unless AddIssue($borrower, $item_1->{barcode});

# Then test:
my $cpvPmappings = [
    {
        msg => "Same item, same patron [1]",
        item => $item_1,
        patron => $patron,
        result => 1,
    },
    {
        msg => "Diff item, same bib, same patron [1]",
        item => $item_2,
        patron => $patron,
        result => 1,
    },
    {
        msg => "Diff item, diff bib, same patron [0]",
        item => $item_d,
        patron => $patron,
        result => 0,
    },
    {
        msg => "Same item, diff patron [0]",
        item => $item_1,
        patron => $patron_d,
        result => 0,
    },
    {
        msg => "Diff item, same bib, diff patron [0]",
        item => $item_2,
        patron => $patron_d,
        result => 0,
    },
    {
        msg => "Diff item, diff bib, diff patron [0]",
        item => $item_d,
        patron => $patron_d,
        result => 0,
    },
];

test_it($cpvPmappings, "PostIssue");

# Return item_1 from patron:
BAIL_OUT("Return Failed") unless AddReturn($item_1->{barcode}, $patron->{branchcode});

# Then:
test_it($cpvPmappings, "PostReturn");

$schema->storage->txn_rollback;

1;
