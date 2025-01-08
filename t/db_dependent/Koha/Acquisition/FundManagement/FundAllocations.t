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

use Test::More tests => 1;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;
use Koha::Acquisition::FundManagement::FundAllocations;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'add_totals_to_fund_allocations' => sub {

    plan tests => 6;

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
                owner_id             => '1',
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

    my $allocation = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 100,
            is_transfer       => 0
        }
    )->store();
    my $allocation2 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 50,
            is_transfer       => 0
        }
    )->store();
    my $allocation3 = Koha::Acquisition::FundManagement::FundAllocation->new(
        {
            fund_id           => $fund->fund_id,
            sub_fund_id       => undef,
            ledger_id         => $ledger->ledger_id,
            fiscal_period_id  => $fiscal_period->fiscal_period_id,
            allocation_amount => 75,
            is_transfer       => 0
        }
    )->store();

    my $sorted_allocations = Koha::Acquisition::FundManagement::FundAllocations->add_totals_to_fund_allocations(
        { allocations => [ $allocation->unblessed, $allocation2->unblessed, $allocation3->unblessed ] } );

    is( @{$sorted_allocations}[0]->{allocation_index}, 1, 'Allocation index set correctly' );
    is( @{$sorted_allocations}[1]->{allocation_index}, 2, 'Allocation index set correctly' );
    is( @{$sorted_allocations}[2]->{allocation_index}, 3, 'Allocation index set correctly' );

    is( @{$sorted_allocations}[0]->{new_fund_value}, 100, 'Fund value set correctly' );
    is( @{$sorted_allocations}[1]->{new_fund_value}, 150, 'Fund value set correctly' );
    is( @{$sorted_allocations}[2]->{new_fund_value}, 225, 'Fund value set correctly' );

    $schema->storage->txn_rollback;
};
