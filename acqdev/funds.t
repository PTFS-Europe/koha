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

    require Koha::Acquire::Funds::Funds;
    require Koha::Schema::Result::KohaPluginAcquireFund;
    Koha::Schema->register_class( KohaPluginAcquireFund => 'Koha::Schema::Result::KohaPluginAcquireFund' );

    require Koha::Acquire::TaskManagement::Tasks;
    require Koha::Schema::Result::KohaPluginAcquireWorkflowTask;
    Koha::Schema->register_class(
        KohaPluginAcquireWorkflowTask => 'Koha::Schema::Result::KohaPluginAcquireWorkflowTask' );

    Koha::Database->schema( { new => 1 } );
}

use Koha::Acquire::Funds::Fund;
use Koha::Acquire::Funds::Funds;
use Koha::Acquire::TaskManagement::Task;
use Koha::Acquire::TaskManagement::Tasks;

warn "Creating fund 1";
my $fund1 = Koha::Acquire::Funds::Fund->new({
    fiscal_yr_id => 1,
    ledger_id    => 3,
    name         => 'Text books',
    code         => 'TB1',
    description  => 'Text books for financial year 2023/2024',
    status       => 1,
    external_id  => 'XeroTB',
    owner        => 51,
    visible_to   => '1',
    currency     => 'GBP',
    fund_type    => 'PRINT'
})->store();

warn "Creating fund 2";
my $fund2 = Koha::Acquire::Funds::Fund->new({
    fiscal_yr_id => 1,
    ledger_id    => 1,
    name         => 'Nature journals',
    code         => 'NAT',
    description  => 'Nature journals for financial year 2023/2024',
    status       => 1,
    external_id  => 'XeroNAT',
    owner        => 51,
    visible_to   => '1',
    currency     => 'GBP',
    fund_type    => 'PRINT'
})->store();

warn "Creating fund 3";
my $fund3 = Koha::Acquire::Funds::Fund->new({
    fiscal_yr_id => 3,
    ledger_id    => 4,
    name         => 'Stationary',
    code         => 'ST1',
    description  => 'Stationary fund for financial year 2023/2024',
    status       => 1,
    external_id  => 'XeroST',
    owner        => 51,
    visible_to   => '11',
    currency     => 'GBP',
    fund_type    => 'MISC'
})->store();

warn "Creating fund 4";
my $fund4 = Koha::Acquire::Funds::Fund->new({
    fiscal_yr_id => 1,
    ledger_id    => 2,
    name         => 'Nature e-journals',
    code         => 'NATE',
    description  => 'Nature e-journals for financial year 2023/2024',
    status       => 1,
    external_id  => 'XeroNATE',
    owner        => 51,
    visible_to   => '11',
    currency     => 'GBP',
    fund_type    => 'MISC'
})->store();

warn "Creating fund 5";
my $fund5 = Koha::Acquire::Funds::Fund->new({
    fiscal_yr_id => 2,
    ledger_id    => 5,
    name         => 'WW2 papers',
    code         => 'WW2',
    description  => 'WW2 papers for financial year 2024/25',
    status       => 0,
    external_id  => 'XeroHIST1',
    owner        => 51,
    visible_to   => '11',
    currency     => 'GBP',
    fund_type    => 'PRINT'
})->store();


warn "Complete";
warn "***YOU NOW NEED TO REINSTALL THE PLUGIN TO RESET THE INC PATH CORRECTLY***";
