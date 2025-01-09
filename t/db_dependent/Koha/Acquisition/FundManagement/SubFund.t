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

use Test::More tests => 2;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Acquisition::FundManagement::SubFunds;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cascade_to_fund_allocations' => sub {

    plan tests => 3;

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
                owner_id             => $ledger->owner_id
            }
        }
    );
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                ledger_id        => $ledger->ledger_id,

                fund_id              => $fund->fund_id,
                lib_group_visibility => '1|2',
                status               => 1,
                currency             => 'GBP',
                owner_id             => '1'
            }
        }
    );
    my $fund_allocation = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FundAllocations',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                ledger_id            => $ledger->ledger_id,
                fund_id              => undef,
                sub_fund_id          => $sub_fund->sub_fund_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                currency             => $ledger->currency,
                owner_id             => $ledger->owner_id
            }
        }
    );

    $fiscal_period->lib_group_visibility('1');
    $fiscal_period->store();

    my $updated_fund_allocation =
        Koha::Acquisition::FundManagement::FundAllocations->find( $fund_allocation->fund_allocation_id );

    is(
        $fiscal_period->lib_group_visibility, $updated_fund_allocation->lib_group_visibility,
        'Fund allocation has updated'
    );

    $sub_fund->currency('USD');
    $sub_fund->owner_id('2');
    $sub_fund->store();

    $updated_fund_allocation =
        Koha::Acquisition::FundManagement::FundAllocations->find( $fund_allocation->fund_allocation_id );

    is( $sub_fund->currency, $updated_fund_allocation->currency, 'Fund allocation has updated' );
    is( $sub_fund->owner_id, $updated_fund_allocation->owner_id, 'Fund allocation has updated' );

    $schema->storage->txn_rollback;
};

subtest 'update_fund_value' => sub {

    plan tests => 1;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2', spend_limit => 0 }
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
                owner_id             => '1',
                ledger_value         => 0,
                spend_limit          => 0
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
    my $sub_fund = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::SubFunds',
            value => {
                fiscal_period_id => $fiscal_period->fiscal_period_id,
                ledger_id        => $ledger->ledger_id,

                fund_id              => $fund->fund_id,
                lib_group_visibility => '1|2',
                status               => 1,
                currency             => 'GBP',
                owner_id             => '1'
            }
        }
    );

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => undef,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 100
        }
    )->store();

    my $updated_sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $sub_fund->sub_fund_id );

    is( $updated_sub_fund->sub_fund_value + 0, 100, 'Fund value is 100' );

    $schema->storage->txn_rollback;
};
