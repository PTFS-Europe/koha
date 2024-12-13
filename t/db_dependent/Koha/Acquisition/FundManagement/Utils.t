#!/usr/bin/perl

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

use Test::More tests => 3;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Acquisition::FundManagement::Funds;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cascade_lib_group_visibility' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2' }
        }
    );
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status,
                currency             => 'GBP',
                owner_id             => '1'
            }
        }
    );

    my $visibility_updated = Koha::Acquisition::FundManagement::Utils->cascade_lib_group_visibility(
        {
            parent_visibility => '1',
            child             => $ledger
        }
    );

    is( $visibility_updated, 1, 'Updated field has been cascaded to the ledger' );

    $visibility_updated = Koha::Acquisition::FundManagement::Utils->cascade_lib_group_visibility(
        {
            parent_visibility => '1|2',
            child             => $ledger
        }
    );

    is( $visibility_updated, 0, 'An expanded range of library group visibility has not been automatically cascaded' );

    $schema->storage->txn_rollback;
};

subtest 'cascade_status' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2' }
        }
    );
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status,
                currency             => 'GBP',
                owner_id             => '1'
            }
        }
    );

    my $status_updated = Koha::Acquisition::FundManagement::Utils->cascade_status(
        {
            parent_status => 0,
            child         => $ledger
        }
    );

    is( $status_updated, 1, 'Updated field has been cascaded to the ledger' );

    $status_updated = Koha::Acquisition::FundManagement::Utils->cascade_status(
        {
            parent_status => 1,
            child         => $ledger
        }
    );

    is( $status_updated, 0, 'Child objects have not been automatically set to active' );

    $schema->storage->txn_rollback;
};

subtest 'cascade_data' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2' }
        }
    );
    my $ledger = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status,
                currency             => 'GBP',
                owner_id             => '1'
            }
        }
    );
    my $fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Funds',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                ledger_id            => $ledger->ledger_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status,
                currency             => $ledger->currency,
                owner_id             => $ledger->owner_id,
                fund_value           => 0
            }
        }
    );

    $ledger->currency('USD');
    $ledger->owner_id('2');
    my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id' );
    my $data_updated    = Koha::Acquisition::FundManagement::Utils->cascade_data(
        {
            parent     => $ledger,
            child      => $fund,
            properties => \@data_to_cascade
        }
    );

    is( $data_updated, 1, 'Updated fields have been cascaded to the ledger' );

    $schema->storage->txn_rollback;
};
