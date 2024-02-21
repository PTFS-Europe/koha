#!/usr/bin/env perl

# Copyright PTFS Europe 2024

# This file is part of Koha.
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
# along with Koha; if not, see <http://www.gnu.olg/licenses>.

use Modern::Perl;

use Koha::Database;
use Koha::Schema;

use JSON qw( decode_json );

BEGIN {
    my $path = '/kohadevbox/koha_plugin/Koha/Plugin/Acquire/lib';
    unshift @INC, $path;

    require Koha::Acquire::Funds::Ledgers;
    require Koha::Schema::Result::KohaPluginAcquireLedger;
    Koha::Schema->register_class( KohaPluginAcquireLedger => 'Koha::Schema::Result::KohaPluginAcquireLedger' );

    require Koha::Acquire::TaskManagement::Tasks;
    require Koha::Schema::Result::KohaPluginAcquireWorkflowTask;
    Koha::Schema->register_class(
        KohaPluginAcquireWorkflowTask => 'Koha::Schema::Result::KohaPluginAcquireWorkflowTask' );

    Koha::Database->schema( { new => 1 } );
}

use Koha::Acquire::Funds::Ledger;
use Koha::Acquire::Funds::Ledgers;
use Koha::Acquire::TaskManagement::Task;
use Koha::Acquire::TaskManagement::Tasks;

create_ledgers();

sub create_ledgers {
    warn "Creating ledger 1";
    my $ledger = Koha::Acquire::Funds::Ledger->new(
        {
            fiscal_yr_id             => 1,
            name                     => 'Print journal ledger',
            code                     => 'P1',
            description              => 'Print journal ledger for financial year 2023/2024',
            status                   => 1,
            external_id              => 'Xero123',
            owner                    => 51,
            visible_to               => '1',
            currency                 => 'GBP',
            over_spend_allowed       => 1,
            over_encumbrance_allowed => 1,
            oe_warning_percent       => 0.1,
            oe_limit_amount          => 100,
            os_warning_sum           => 100,
            os_limit_sum             => 100,
        }
    )->store();
    warn "Creating ledger 2";
    my $ledger2 = Koha::Acquire::Funds::Ledger->new(
        {
            fiscal_yr_id             => 1,
            name                     => 'Electronic journal ledger',
            code                     => 'E1',
            description              => 'Electronic journal for financial year 2023/2024',
            status                   => 1,
            external_id              => 'Xero456',
            owner                    => 51,
            visible_to               => '1',
            currency                 => 'GBP',
            over_spend_allowed       => 1,
            over_encumbrance_allowed => 1,
            oe_warning_percent       => 0.1,
            oe_limit_amount          => 100,
            os_warning_sum           => 100,
            os_limit_sum             => 100,
        }
    )->store();
    warn "Creating ledger 3";
    my $ledger3 = Koha::Acquire::Funds::Ledger->new(
        {
            fiscal_yr_id             => 1,
            name                     => 'Academic materials',
            code                     => 'AC1',
            description              => 'Academic materials for financial year 2023/2024',
            status                   => 1,
            external_id              => 'XeroABC',
            owner                    => 51,
            visible_to               => '1',
            currency                 => 'GBP',
            over_spend_allowed       => 1,
            over_encumbrance_allowed => 1,
            oe_warning_percent       => 0.1,
            oe_limit_amount          => 100,
            os_warning_sum           => 100,
            os_limit_sum             => 100,
        }
    )->store();
    warn "Creating ledger 4";
    my $ledger4 = Koha::Acquire::Funds::Ledger->new(
        {
            fiscal_yr_id             => 3,
            name                     => 'Misc funds',
            code                     => 'MISC1',
            description              => 'Miscellaneous funds for 2024',
            status                   => 1,
            external_id              => 'XeroMISC',
            owner                    => 51,
            visible_to               => '11',
            currency                 => 'GBP',
            over_spend_allowed       => 0,
            over_encumbrance_allowed => 0,
            oe_warning_percent       => 0,
            oe_limit_amount          => 0,
            os_warning_sum           => 0,
            os_limit_sum             => 0,
        }
    )->store();

    warn "Creating ledger 5";
    my $ledger5 = Koha::Acquire::Funds::Ledger->new(
        {
            fiscal_yr_id             => 2,
            name                     => 'History journals',
            code                     => 'HIST1',
            description              => 'Historical journals for FY 2024/25',
            status                   => 1,
            external_id              => 'XeroHIST',
            owner                    => 51,
            visible_to               => '11',
            currency                 => 'GBP',
            over_spend_allowed       => 1,
            over_encumbrance_allowed => 1,
            oe_warning_percent       => 0.2,
            oe_limit_amount          => 150,
            os_warning_sum           => 100,
            os_limit_sum             => 200,
        }
    )->store();

    warn "Creating task for ledger 1";
    my $task = Koha::Acquire::TaskManagement::Task->new(
        {
            short_name  => 'Add fund to ledger ABC',
            module      => 'funds',
            description => 'Add a new fund for this ledger',
            created_on  => '2024-02-20',
            created_by  => 51,
            end_date    => '2024-04-01',
            status      => 'assigned',
            owner       => 54
        }
    )->store();

}
