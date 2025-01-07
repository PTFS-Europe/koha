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

use Test::More tests => 9;
use Test::MockModule;

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

subtest 'total_spent' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '|' . $library->branchcode . '|', spend_limit => 100 }
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
            spend_limit          => 50
        }
    )->store();

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10,
            type              => 'spent'
        }
    )->store();

    is( $fiscal_period->total_spent + 0, -10, 'Total spent is -10' );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -5,
            type              => 'spent'
        }
    )->store();

    is( $fiscal_period->total_spent + 0, -15, 'Total spent is -15' );

    # encumbrance rather than spend
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10,
            type              => 'encumbered'
        }
    )->store();

    is( $fiscal_period->total_spent + 0, -15, 'Total spent is still -15' );

    $schema->storage->txn_rollback;
};

subtest 'total_encumbered' => sub {

    plan tests => 3;

    $schema->storage->txn_begin;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => "|" . $library->branchcode . "|", spend_limit => 100 }
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
            spend_limit          => 50
        }
    )->store();

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10,
            type              => 'encumbered'
        }
    )->store();

    is( $fiscal_period->total_encumbered + 0, -10, 'Total encumbered is -10' );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -5,
            type              => 'encumbered'
        }
    )->store();

    is( $fiscal_period->total_encumbered + 0, -15, 'Total encumbered is -15' );

    # Spend rather than encumbrance
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10,
            type              => 'spent'
        }
    )->store();

    is( $fiscal_period->total_encumbered + 0, -15, 'Total encumbered is still -15' );

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

subtest 'add_accounting_values' => sub {

    plan tests => 4;

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
            spend_limit          => 50
        }
    )->store();
    my $fund2 = Koha::Acquisition::FundManagement::Fund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            spend_limit          => 50
        }
    )->store();
    my $sub_fund = Koha::Acquisition::FundManagement::SubFund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            fund_id              => $fund2->fund_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            spend_limit          => 50
        }
    )->store();

    my $allocation1 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -15
        }
    )->store();
    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -5
        }
    )->store();
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund2->fund_id,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10
        }
    )->store();
    my $allocation4 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund2->fund_id,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 10,
            type              => 'credit'
        }
    )->store();

    $sub_fund                     = $sub_fund->unblessed;
    $sub_fund->{fund_allocations} = [ $allocation3->unblessed, $allocation4->unblessed ];
    $fund                         = $fund->unblessed;
    $fund->{fund_allocations}     = [ $allocation1->unblessed, $allocation2->unblessed ];
    $fund2                        = $fund2->unblessed;
    $fund2->{sub_funds}           = [$sub_fund];
    my $data = $ledger->unblessed;
    $data->{funds} = [ $fund, $fund2 ];
    my $result = $ledger->add_accounting_values( { data => $data } );

    is( $result->{total_allocation},    -20, 'Total allocations is -20' );
    is( $result->{allocation_decrease}, -30, 'Total decrease is -30' );
    is( $result->{allocation_increase}, 10,  'Total allocations is 10' );
    is( $result->{net_transfers},       0,   'Total allocations is 0' );

    $schema->storage->txn_rollback;
};
