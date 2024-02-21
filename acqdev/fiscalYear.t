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

    require Koha::Acquire::Funds::FiscalYears;
    require Koha::Schema::Result::KohaPluginAcquireFiscalYear;
    Koha::Schema->register_class( KohaPluginAcquireFiscalYear => 'Koha::Schema::Result::KohaPluginAcquireFiscalYear' );

    require Koha::Acquire::TaskManagement::Tasks;
    require Koha::Schema::Result::KohaPluginAcquireWorkflowTask;
    Koha::Schema->register_class(
        KohaPluginAcquireWorkflowTask => 'Koha::Schema::Result::KohaPluginAcquireWorkflowTask' );

    Koha::Database->schema( { new => 1 } );
}

use Koha::Acquire::Funds::FiscalYear;
use Koha::Acquire::Funds::FiscalYears;
use Koha::Acquire::TaskManagement::Task;
use Koha::Acquire::TaskManagement::Tasks;

warn "Creating fiscal year 1";
my $fy1 = Koha::Acquire::Funds::FiscalYear->new({
    code => 'FY 23/24',
    description => 'Financial year 2023/2024',
    status => 1,
    start_date => '2023-04-01',
    end_date => '2024-03-31',
    owner => 51,
    visible_to => '1|11'
})->store();

warn "Creating fiscal year 2";
my $fy2 = Koha::Acquire::Funds::FiscalYear->new({
    code => 'FY 24/25',
    description => 'Financial year 2024/2025',
    status => 0,
    start_date => '2024-04-01',
    end_date => '2025-03-31',
    owner => 51,
    visible_to => '1|11'
})->store();

warn "Creating fiscal year 3";
my $fy3 = Koha::Acquire::Funds::FiscalYear->new({
    code => 'CY 23/24',
    description => 'Calendar year 2023/2024',
    status => 1,
    start_date => '2024-01-01',
    end_date => '2024-12-31',
    owner => 51,
    visible_to => '11'
})->store();

warn "Creating task for fiscal year 2";
my $task = Koha::Acquire::TaskManagement::Task->new({
    short_name => 'Activate FY 24/25',
    module => 'funds',
    description => 'Financial year for 24/25 needs activating once the current FY has ended',
    created_on => '2024-02-20',
    created_by => 19,
    end_date => '2024-04-01',
    status => 'assigned',
    owner => 51
})->store();

warn "Creating task for fiscal year 1";
my $task2 = Koha::Acquire::TaskManagement::Task->new({
    short_name => 'Activate FY 23/24',
    module => 'funds',
    description => 'Financial year for 23/24 needs activating once the current FY has ended',
    created_on => '2024-02-20',
    created_by => 19,
    end_date => '2024-04-01',
    status => 'complete',
    owner => 51
})->store();

warn "Complete";
warn "***YOU NOW NEED TO REINSTALL THE PLUGIN TO RESET THE INC PATH CORRECTLY***";
