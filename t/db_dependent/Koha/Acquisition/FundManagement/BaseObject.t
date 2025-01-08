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

use Test::More tests => 12;
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

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );

    t::lib::Mocks::mock_userenv( { branchcode => $library->branchcode } );

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

    is( $fiscal_period->total_allocations + 0, -10, 'Total spent is -10' );

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

    is( $fiscal_period->total_allocations + 0, -15, 'Total spent is -15' );

    # Positive allocation to simulate a transfer from another fund or a credit note
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 15,
            type              => 'spent'
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
            spend_limit          => 100,
            over_spend_allowed   => 0,
            oe_warning_percent   => 0.50,
            oe_limit_amount      => 85,
            os_warning_sum       => 75,
            os_limit_sum         => 90
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

    my $result = $ledger->is_spend_limit_breached( { new_allocation => $allocation } );
    is( $result->{within_limit}, 1, 'Within limit' );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -91,
            type              => 'spent'
        }
    );

    $result = $ledger->is_spend_limit_breached( { new_allocation => $allocation2 } );
    is( $result->{breach_amount}, 1, 'Breached by 1' );

    # Warnings
    $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -40,
            type              => 'encumbered'
        }
    );

    $result = $ledger->is_spend_limit_breached( { new_allocation => $allocation2 } );
    is( $result->{within_limit}, 1, 'No breach' );
    is( $result->{oe_warning},   1, 'Warning for encumbrance triggered' );

    $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -65,
            type              => 'spent'
        }
    );

    $result = $ledger->is_spend_limit_breached( { new_allocation => $allocation2 } );
    is( $result->{within_limit}, 1, 'No breach' );
    is( $result->{os_warning},   1, 'Warning for spend triggered' );

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
            allocation_amount => -15,
            type              => 'spent'
        }
    )->store();
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
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund2->fund_id,
            sub_fund_id       => $sub_fund->sub_fund_id,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -10,
            type              => 'spent'
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

subtest 'verify_updated_fields' => sub {

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
            spend_limit          => 100,
            over_spend_allowed   => 1,
        }
    )->store();

    # The sub methods have their own tests, here we just need to check that they are called and the error is passed back correctly
    my $module = Test::MockModule->new('Koha::Acquisition::FundManagement::BaseObject');
    $module->mock(
        'handle_spending_block_changes',
        sub {
            return 'Error with spending blocks';
        }
    );

    $module->mock(
        'handle_spend_limit_changes',
        sub {
            return 'Error with spend_limit';
        }
    );

    # If over_spend_allowed or over_spend_encumbrance are allowed, no check is needed
    my $updated_fields = {
        over_spend_allowed => 1,
        spend_limit        => 100
    };

    my $error = $ledger->verify_updated_fields( { updated_fields => $updated_fields } );
    is( $error, undef, 'No check run so no error reported' );

    $updated_fields = {
        over_spend_allowed => 0,
        spend_limit        => 100
    };

    $error = $ledger->verify_updated_fields( { updated_fields => $updated_fields } );
    is( $error, 'Error with spending blocks', 'Spending block check has run and returned an error' );

    $updated_fields = {
        over_spend_allowed => 1,
        spend_limit        => 200
    };

    $error = $ledger->verify_updated_fields( { updated_fields => $updated_fields } );
    is( $error, 'Error with spend_limit', 'Spend_limit check has run and returned an error' );

    $schema->storage->txn_rollback;
};

subtest 'handle_spending_block_changes' => sub {

    plan tests => 2;

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
            spend_limit          => 100,
            over_spend_allowed   => 1,
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
            spend_limit          => 50,
            over_spend_allowed   => 1,
        }
    )->store();

    my $allocation1 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -50,
            type              => 'spent'
        }
    )->store();

    my $error = $ledger->handle_spending_block_changes( { spend => 0 } );
    is( $error, undef, 'Ledger has no over spend so no check required' );

    my $module = Test::MockModule->new('Koha::Acquisition::FundManagement::FundAllocation');
    $module->mock(
        'will_allocation_breach_spend_limits',
        sub {
            return 0;
        }
    );

    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => -51,
            type              => 'spent'
        }
    )->store();

    $error = $ledger->handle_spending_block_changes( { spend => 0 } );
    is(
        $error, "You cannot prevent overspend on a ledger that is already overspent"
        ,       'Overspend correctly identified so over_spend_allowed cannot be set to 0'
    );

    $schema->storage->txn_rollback;
};

subtest 'handle_spend_limit_changes' => sub {

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
            spend_limit          => 100,
            over_spend_allowed   => 1,
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
            spend_limit          => 50,
            over_spend_allowed   => 1,
        }
    )->store();

    my $error = $ledger->handle_spend_limit_changes( { new_limit => 60, over_spend_allowed => 0 } );
    is( $error, undef, 'Ledger spend_limit still greater than that of its funds' );

    my $fund2 = Koha::Acquisition::FundManagement::Fund->new(
        {
            fiscal_period_id     => $fiscal_period->fiscal_period_id,
            ledger_id            => $ledger->ledger_id,
            lib_group_visibility => $fiscal_period->lib_group_visibility,
            status               => $fiscal_period->status,
            currency             => $ledger->currency,
            owner_id             => $ledger->owner_id,
            spend_limit          => 50,
            over_spend_allowed   => 1,
        }
    )->store();

    $error = $ledger->handle_spend_limit_changes( { new_limit => 90, over_spend_allowed => 0 } );
    is(
        $error,
        "The ledger spend limit is less than the total of the spend limits for the funds below, please increase spend limit by 10 or decrease the spend limit for the funds",
        'Correctly identifies an insufficient spend_limit on the ledger'
    );

    $error = $ledger->handle_spend_limit_changes( { new_limit => 110, over_spend_allowed => 0 } );
    is(
        $error,
        "Spend limit breached for the fiscal period, please reduce the spend limit on the ledger by 10 or increase the spend limit for the fiscal period",
        'Correctly identifies that the spend_limit is now too high on the ledger'
    );

    $schema->storage->txn_rollback;
};
