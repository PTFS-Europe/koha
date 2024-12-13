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
use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::FiscalPeriods;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'cascade_to_ledgers' => sub {

    plan tests => 4;

    $schema->storage->txn_begin;

    my $fiscal_period = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::FiscalPeriods',
            value => { status => 1, lib_group_visibility => '1|2' }
        }
    );
    my $ledger_1 = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status
            }
        }
    );

    my $ledger_2 = $builder->build_object(
        {
            class => 'Koha::Acquisition::FundManagement::Ledgers',
            value => {
                fiscal_period_id     => $fiscal_period->fiscal_period_id,
                lib_group_visibility => $fiscal_period->lib_group_visibility,
                status               => $fiscal_period->status
            }
        }
    );

    $fiscal_period->status(0);
    $fiscal_period->lib_group_visibility('1');
    $fiscal_period->store();

    my $updated_ledger_1 = Koha::Acquisition::FundManagement::Ledgers->find( $ledger_1->ledger_id );
    my $updated_ledger_2 = Koha::Acquisition::FundManagement::Ledgers->find( $ledger_2->ledger_id );

    is( $fiscal_period->status,               $updated_ledger_1->status,               'Ledger one has updated' );
    is( $fiscal_period->status,               $updated_ledger_2->status,               'Ledger two has updated' );
    is( $fiscal_period->lib_group_visibility, $updated_ledger_1->lib_group_visibility, 'Ledger one has updated' );
    is( $fiscal_period->lib_group_visibility, $updated_ledger_2->lib_group_visibility, 'Ledger two has updated' );

    $schema->storage->txn_rollback;

};
