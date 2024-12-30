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
use Koha::Acquisition::FundManagement::Ledgers;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cascade_to_funds' => sub {

    plan tests => 5;

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

    $fiscal_period->status(0);
    $fiscal_period->store();

    my $updated_ledger = Koha::Acquisition::FundManagement::Ledgers->find( $ledger->ledger_id );
    my $updated_fund   = Koha::Acquisition::FundManagement::Funds->find( $fund->fund_id );

    is( $fiscal_period->status, $updated_ledger->status, 'Ledger has updated' );
    is( $fiscal_period->status, $updated_fund->status,   'Fund has updated' );

    $ledger->lib_group_visibility('1');
    $ledger->currency('USD');
    $ledger->owner_id('2');
    $ledger->store();

    $updated_fund = Koha::Acquisition::FundManagement::Funds->find( $fund->fund_id );

    is( $ledger->lib_group_visibility, $updated_fund->lib_group_visibility, 'Fund has updated' );
    is( $ledger->currency,             $updated_fund->currency,             'Fund has updated' );
    is( $ledger->owner_id,             $updated_fund->owner_id,             'Fund has updated' );

    $schema->storage->txn_rollback;
};

