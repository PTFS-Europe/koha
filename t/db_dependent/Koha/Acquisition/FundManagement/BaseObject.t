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

use Test::More tests => 7;

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

    my $visibility_updated = $fiscal_period->cascade_lib_group_visibility(
        {
            parent_visibility => '1',
            child             => $ledger
        }
    );

    is( $visibility_updated, 1, 'Updated field has been cascaded to the ledger' );

    $visibility_updated = $fiscal_period->cascade_lib_group_visibility(
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

    my $status_updated = $fiscal_period->cascade_status(
        {
            parent_status => 0,
            child         => $ledger
        }
    );

    is( $status_updated, 1, 'Updated field has been cascaded to the ledger' );

    $status_updated = $fiscal_period->cascade_status(
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
    my $data_updated    = $ledger->cascade_data(
        {
            parent     => $ledger,
            child      => $fund,
            properties => \@data_to_cascade
        }
    );

    is( $data_updated, 1, 'Updated fields have been cascaded to the ledger' );

    $schema->storage->txn_rollback;
};

subtest 'update_object_value' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2', spend_limit => 100 }
        }
    );
    my $ledger = Koha::Acquisition::FundManagement::Ledger->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => 'GBP',
            owner_id             => '1',
            ledger_value         => 0,
            spend_limit          => 100
        }
    )->store();
    my $fund = Koha::Acquisition::FundManagement::Fund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            fund_value           => 0,
            spend_limit          => 50
        }
    )->store();
    my $sub_fund = Koha::Acquisition::FundManagement::SubFund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            fund_id              => $fund->fund_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            sub_fund_value       => 0,
            spend_limit          => 25
        }
    )->store();

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => undef,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10
        }
    )->store();

    my $updated_ledger = Koha::Acquisition::FundManagement::Ledgers->find( $ledger->ledger_id );
    is( $updated_ledger->ledger_value + 0, 90, 'Ledger value is reduced from 100 to 90' );

    my $updated_fund = Koha::Acquisition::FundManagement::Funds->find( $fund->fund_id );
    is( $updated_fund->fund_value + 0, 40, 'Fund value is reduced from 50 to 40' );

    my $updated_sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $sub_fund->sub_fund_id );
    is( $updated_sub_fund->sub_fund_value + 0, 15, 'Sub fund value is reduced from 25 to 15' );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => undef,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -5
        }
    )->store();

    $updated_ledger = Koha::Acquisition::FundManagement::Ledgers->find( $ledger->ledger_id );
    is( $updated_ledger->ledger_value + 0, 85, 'Ledger value is reduced from 90 to 85' );

    $updated_fund = Koha::Acquisition::FundManagement::Funds->find( $fund->fund_id );
    is( $updated_fund->fund_value + 0, 35, 'Fund value is reduced from 40 to 35' );

    $updated_sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $sub_fund->sub_fund_id );
    is( $updated_sub_fund->sub_fund_value + 0, 10, 'Sub fund value is reduced from 15 to 10' );

    $schema->storage->txn_rollback;
};

subtest 'total_allocations' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2', spend_limit => 100 }
        }
    );
    my $ledger = Koha::Acquisition::FundManagement::Ledger->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => 'GBP',
            owner_id             => '1',
            ledger_value         => 0,
            spend_limit          => 100
        }
    )->store();
    my $fund = Koha::Acquisition::FundManagement::Fund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            fund_value           => 0,
            spend_limit          => 50
        }
    )->store();

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10
        }
    )->store();

    is( $fiscal_period->total_allocations + 0, -10, 'Total spent is -10' );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -5
        }
    )->store();

    is( $fiscal_period->total_allocations + 0, -15, 'Total spent is -15' );

    # Positive allocation to simulate a transfer from another fund or a credit note
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 15
        }
    )->store();

    is( $fiscal_period->total_allocations + 0, 0, 'Total spent is 0' );

    $schema->storage->txn_rollback;
};

subtest 'check_spend_limits' => sub {

    plan tests => 6;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2', spend_limit => 100 }
        }
    );
    my $ledger = Koha::Acquisition::FundManagement::Ledger->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => 'GBP',
            owner_id             => '1',
            ledger_value         => 0,
            spend_limit          => 100
        }
    )->store();
    my $fund = Koha::Acquisition::FundManagement::Fund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            fund_value           => 0,
            spend_limit          => 50
        }
    )->store();

    my $result = $ledger->check_spend_limits( { new_allocation => 0 } );
    is( $result->{within_limit},  1, 'Within limit' );
    is( $result->{breach_amount}, 0, 'No breach found' );

    $result = $ledger->check_spend_limits( { new_allocation => 50 } );
    is( $result->{within_limit},  1, 'Still within limit' );
    is( $result->{breach_amount}, 0, 'No breach found' );

    $result = $ledger->check_spend_limits( { new_allocation => 51 } );
    is( $result->{within_limit},  0, 'Limit has been breached' );
    is( $result->{breach_amount}, 1, 'Breached by 1' );

    $schema->storage->txn_rollback;
};

subtest 'is_spend_limit_breached' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2', spend_limit => 100 }
        }
    );

    my $result = $fiscal_period->is_spend_limit_breached( { new_allocation => -100 } );
    is( $result->{within_limit}, 1, 'Within limit' );
    $result = $fiscal_period->is_spend_limit_breached( { new_allocation => -101 } );
    is( $result->{breach_amount}, 1, 'Breached by 1' );

    $schema->storage->txn_rollback;
};
