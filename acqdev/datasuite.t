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

use t::lib::TestBuilder;

use Koha::Database;
use Koha::Schema;

use JSON qw( decode_json );

BEGIN {
    my $path = '/kohadevbox/plugins/koha-plugin-acq2/Koha/Plugin/Acquire/lib';
    unshift @INC, $path;

    require Koha::Acquire::Funds::FiscalYears;
    require Koha::Schema::Result::KohaPluginAcquireFiscalYear;
    Koha::Schema->register_class( KohaPluginAcquireFiscalYear => 'Koha::Schema::Result::KohaPluginAcquireFiscalYear' );

    require Koha::Acquire::Funds::Ledgers;
    require Koha::Schema::Result::KohaPluginAcquireLedger;
    Koha::Schema->register_class( KohaPluginAcquireLedger => 'Koha::Schema::Result::KohaPluginAcquireLedger' );

    require Koha::Acquire::Funds::Funds;
    require Koha::Schema::Result::KohaPluginAcquireFund;
    Koha::Schema->register_class( KohaPluginAcquireFund => 'Koha::Schema::Result::KohaPluginAcquireFund' );

    require Koha::Acquire::Funds::SubFunds;
    require Koha::Schema::Result::KohaPluginAcquireSubFund;
    Koha::Schema->register_class( KohaPluginAcquireSubFund => 'Koha::Schema::Result::KohaPluginAcquireSubFund' );

    require Koha::Acquire::Funds::FundGroups;
    require Koha::Schema::Result::KohaPluginAcquireFundGroup;
    Koha::Schema->register_class( KohaPluginAcquireFundGroup => 'Koha::Schema::Result::KohaPluginAcquireFundGroup' );

    require Koha::Acquire::Funds::FundAllocations;
    require Koha::Schema::Result::KohaPluginAcquireFundAllocation;
    Koha::Schema->register_class( KohaPluginAcquireFundAllocation => 'Koha::Schema::Result::KohaPluginAcquireFundAllocation' );

    require Koha::Acquire::TaskManagement::Tasks;
    require Koha::Schema::Result::KohaPluginAcquireWorkflowTask;
    Koha::Schema->register_class(
        KohaPluginAcquireWorkflowTask => 'Koha::Schema::Result::KohaPluginAcquireWorkflowTask' );

    Koha::Database->schema( { new => 1 } );
}

use Koha::Patrons;
use Koha::Library::Groups;
use Koha::Acquire::Funds::FiscalYear;
use Koha::Acquire::Funds::FiscalYears;
use Koha::Acquire::Funds::Ledger;
use Koha::Acquire::Funds::Ledgers;
use Koha::Acquire::Funds::Fund;
use Koha::Acquire::Funds::Funds;
use Koha::Acquire::TaskManagement::Task;
use Koha::Acquire::TaskManagement::Tasks;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

# Select which data you would like to add by commenting out lines below

create_library_groups();
create_patrons( { branchcode => 'CPL' } );
create_patrons( { branchcode => 'FPL' } );
create_patrons( { branchcode => 'MPL' } );
create_patrons( { branchcode => 'TPL' } );
create_patrons( { branchcode => 'FFL' } );
create_fiscal_years();
create_ledgers();
create_funds();
create_fund_allocations();

# Clears the plugin tables to allow quick reinstall of the plugin as per the warns below
clear_plugin_data();
warn "Plugin data reset";

warn "\n\n\n\n***YOU NOW NEED TO REINSTALL THE PLUGIN TO RESET THE INC PATH CORRECTLY***";
warn "Quick method:\n- In ktd shell: perl /kohadevbox/koha/misc/devel/install_plugins.pl\n- In ktd shell: restart_all";

sub create_library_groups {
    warn "Adding group 1";

    # Group 1 - two sub groups: A, B. Sub group A then has two sub groups: A1, A2
    my $root_group1 = Koha::Library::Group->new(
        {
            title           => "LibGroup1",
            ft_acquisitions => 1
        }
    )->store();

    my $lg1groupA = Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupA' } )->store();
    my $lg1groupA1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, title => 'LibGroup1 SubGroupA SubGroup1' } )->store();
    my $lg1groupA2 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, title => 'LibGroup1 SubGroupA SubGroup2' } )->store();
    my $lg1groupB = Koha::Library::Group->new( { parent_id => $root_group1->id, title => 'LibGroup1 SubGroupB' } )->store();

    my $lg1groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => 'CPL' } )->store();
    my $lg1groupA_library2 =
        Koha::Library::Group->new( { parent_id => $lg1groupA->id, branchcode => 'FPL' } )->store();
    my $lg1groupB_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupB->id, branchcode => 'CPL' } )->store();
    my $lg1groupA1_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA1->id, branchcode => 'FPL' } )->store();
    my $lg1groupA2_library1 =
        Koha::Library::Group->new( { parent_id => $lg1groupA2->id, branchcode => 'CPL' } )->store();

    warn "Adding group 2";

    # Group 2 - three sub groups: A, B, C. Sub group A then has two sub groups: A1, A2 and sub group C has two: C1, C2
    my $root_group2 = Koha::Library::Group->new(
        {
            title           => "LibGroup2",
            ft_acquisitions => 1
        }
    )->store();

    my $lg2groupA = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupA' } )->store();
    my $lg2groupA1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, title => 'LibGroup2 SubGroupA SubGroup1' } )->store();
    my $lg2groupA2 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, title => 'LibGroup2 SubGroupA SubGroup2' } )->store();
    my $lg2groupB = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupB' } )->store();
    my $lg2groupC = Koha::Library::Group->new( { parent_id => $root_group2->id, title => 'LibGroup2 SubGroupC' } )->store();
    my $lg2groupC1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, title => 'LibGroup2 SubGroupC SubGroup1' } )->store();
    my $lg2groupC2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, title => 'LibGroup2 SubGroupC SubGroup2' } )->store();

    my $lg2groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => 'CPL' } )->store();
    my $lg2groupA_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupA->id, branchcode => 'MPL' } )->store();
    my $lg2groupB_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupB->id, branchcode => 'CPL' } )->store();
    my $lg2groupC_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'CPL' } )->store();
    my $lg2groupC_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'MPL' } )->store();
    my $lg2groupC_library3 =
        Koha::Library::Group->new( { parent_id => $lg2groupC->id, branchcode => 'TPL' } )->store();
    my $lg2groupA1_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA1->id, branchcode => 'MPL' } )->store();
    my $lg2groupA2_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupA2->id, branchcode => 'CPL' } )->store();
    my $lg2groupC1_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC1->id, branchcode => 'MPL' } )->store();
    my $lg2groupC2_library1 =
        Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => 'CPL' } )->store();
    my $lg2groupC2_library2 =
        Koha::Library::Group->new( { parent_id => $lg2groupC2->id, branchcode => 'TPL' } )->store();

    warn "Adding group 3";

    # Group 3 - This group does not contain 'CPL' to check that it is being missed in the filtering
    my $root_group3 = Koha::Library::Group->new(
        {
            title           => "LibGroup3",
            ft_acquisitions => 1
        }
    )->store();

    my $lg3groupA = Koha::Library::Group->new( { parent_id => $root_group3->id, title => 'LibGroup3 SubGroupA' } )->store();
    my $lg3groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg3groupA->id, branchcode => 'FFL' } )->store();

    warn "Adding group 4";

    # Group 3 - This group does not apply to the acquisitions module and therefore should never appear
    my $root_group4 = Koha::Library::Group->new(
        {
            title           => "LibGroup4",
            ft_acquisitions => 0
        }
    )->store();

    my $lg4groupA = Koha::Library::Group->new( { parent_id => $root_group4->id, title => 'LibGroup4 SubGroupA' } )->store();
    my $lg4groupA_library1 =
        Koha::Library::Group->new( { parent_id => $lg4groupA->id, branchcode => 'CPL' } )->store();

    warn "All library groups added";

}

sub create_patrons {
    my ($args) = @_;

    my $branchcode = $args->{branchcode};

    my $patrons = _get_patrons_to_load($branchcode);

    foreach my $record ( keys %$patrons ) {
        my $details     = $patrons->{$record}->{details};
        my $patron      = $builder->build_object( { class => 'Koha::Patrons', value => $details } );
        $patron->set_password({ password => 'Test1234' });
        my $permissions = $patrons->{$record}->{permissions} || {};

        foreach my $permission ( keys %$permissions ) {
            if ( $permissions->{$permission} ) {
                $builder->build(
                    {
                        source => 'UserPermission',
                        value  => {
                            borrowernumber => $patron->borrowernumber,
                            module_bit     => 11,
                            code           => $permission,
                        },
                    }
                );
            }
        }
    }
    warn "Patrons loaded for branch $branchcode";
}

sub create_fiscal_years {

    warn "Creating fiscal year 1";
    my $fy1 = Koha::Acquire::Funds::FiscalYear->new(
        {
            code        => 'FY 23/24',
            description => 'Financial year 2023/2024',
            status      => 1,
            start_date  => '2023-04-01',
            end_date    => '2024-03-31',
            owner       => 51,
            visible_to  => '1|11'
        }
    )->store();

    warn "Creating fiscal year 2";
    my $fy2 = Koha::Acquire::Funds::FiscalYear->new(
        {
            code        => 'FY 24/25',
            description => 'Financial year 2024/2025',
            status      => 0,
            start_date  => '2024-04-01',
            end_date    => '2025-03-31',
            owner       => 51,
            visible_to  => '1|11'
        }
    )->store();

    warn "Creating fiscal year 3";
    my $fy3 = Koha::Acquire::Funds::FiscalYear->new(
        {
            code        => 'CY 23/24',
            description => 'Calendar year 2023/2024',
            status      => 1,
            start_date  => '2024-01-01',
            end_date    => '2024-12-31',
            owner       => 51,
            visible_to  => '11'
        }
    )->store();

    warn "Creating task for fiscal year 2";
    my $task = Koha::Acquire::TaskManagement::Task->new(
        {
            short_name  => 'Activate FY 24/25',
            module      => 'funds',
            description => 'Financial year for 24/25 needs activating once the current FY has ended',
            created_on  => '2024-02-20',
            created_by  => 19,
            end_date    => '2024-04-01',
            status      => 'assigned',
            owner       => 51
        }
    )->store();

    warn "Creating task for fiscal year 1";
    my $task2 = Koha::Acquire::TaskManagement::Task->new(
        {
            short_name  => 'Activate FY 23/24',
            module      => 'funds',
            description => 'Financial year for 23/24 needs activating once the current FY has ended',
            created_on  => '2024-02-20',
            created_by  => 19,
            end_date    => '2024-04-01',
            status      => 'complete',
            owner       => 51
        }
    )->store();

    warn "All fiscal years added";
}

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
            visible_to               => '1|11',
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

    warn "Ledgers complete";

}

sub create_funds {
    warn "Creating fund 1";
    my $fund1 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 1,
            ledger_id    => 3,
            name         => 'Text books',
            code         => 'TB1',
            description  => 'Text books for financial year 2023/2024',
            status       => 1,
            external_id  => 'XeroTB',
            owner        => 51,
            visible_to   => '1|11',
            currency     => 'GBP',
            fund_type    => 'PRINT'
        }
    )->store();

    warn "Creating fund 2";
    my $fund2 = Koha::Acquire::Funds::Fund->new(
        {
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
        }
    )->store();

    warn "Creating fund 3";
    my $fund3 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 3,
            ledger_id    => 4,
            name         => 'Stationery',
            code         => 'ST1',
            description  => 'Stationery fund for financial year 2023/2024',
            status       => 1,
            external_id  => 'XeroST',
            owner        => 51,
            visible_to   => '11',
            currency     => 'GBP',
            fund_type    => 'MISC'
        }
    )->store();

    warn "Creating fund 4";
    my $fund4 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 1,
            ledger_id    => 2,
            name         => 'Nature e-journals',
            code         => 'NAT-E',
            description  => 'Nature e-journals for financial year 2023/2024',
            status       => 1,
            external_id  => 'XeroNAT-E',
            owner        => 51,
            visible_to   => '1',
            currency     => 'GBP',
            fund_type    => 'MISC'
        }
    )->store();

    warn "Creating fund 5";
    my $fund5 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 2,
            ledger_id    => 5,
            name         => 'Science journals',
            code         => 'SCI',
            description  => 'Scientific journals for financial year 2024/25',
            status       => 1,
            external_id  => 'XeroHIST1',
            owner        => 51,
            visible_to   => '11',
            currency     => 'GBP',
            fund_type    => 'PRINT'
        }
    )->store();

    warn "Creating fund 6";
    my $fund6 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 1,
            ledger_id    => 1,
            name         => 'Print resources',
            code         => 'BKS',
            description  => 'Additional print resources for financial year 2024/25',
            status       => 1,
            external_id  => 'XeroPRINT1',
            owner        => 51,
            visible_to   => '1',
            currency     => 'GBP',
            fund_type    => 'PRINT'
        }
    )->store();

    warn "Creating fund 7";
    my $fund7 = Koha::Acquire::Funds::Fund->new(
        {
            fiscal_yr_id => 1,
            ledger_id    => 3,
            name         => 'Fund for stuff',
            code         => 'STUFF',
            description  => 'Additional stuffs for financial year 2024/25',
            status       => 0,
            external_id  => 'XeroPRINT1',
            owner        => 51,
            visible_to   => '1',
            currency     => 'GBP',
            fund_type    => 'PRINT'
        }
    )->store();

    warn "Funds complete";
}

sub create_fund_allocations {
    warn "Creating fund allocation 1";
    my $allocation1 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 1,
            sub_fund_id => undef,
            ledger_id => 3,
            fiscal_yr_id => 1,
            allocation_amount => 1000,
            reference => 'Ref1',
            note => 'Setup allocation',
            currency => 'GBP',
            owner => 51,
            visible_to => '1|11'
        }
    )->store();
    warn "Creating fund allocation 2";
    my $allocation2 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 1,
            sub_fund_id => undef,
            ledger_id => 3,
            fiscal_yr_id => 1,
            allocation_amount => 200,
            reference => 'Ref2',
            note => 'Extra funds',
            currency => 'GBP',
            owner => 51,
            visible_to => '1|11'
        }
    )->store();
    warn "Creating fund allocation 3";
    my $allocation3 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 2,
            sub_fund_id => undef,
            ledger_id => 1,
            fiscal_yr_id => 1,
            allocation_amount => 2500,
            reference => 'Ref1',
            note => 'Journal funds',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();
    warn "Creating fund allocation 4";
    my $allocation4 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 2,
            sub_fund_id => undef,
            ledger_id => 1,
            fiscal_yr_id => 1,
            allocation_amount => 200,
            reference => 'Ref2',
            note => '',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();
    warn "Creating fund allocation 5";
    my $allocation5 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 2,
            sub_fund_id => undef,
            ledger_id => 1,
            fiscal_yr_id => 1,
            allocation_amount => -200,
            reference => 'Ref3',
            note => 'Re-balancing',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();
    warn "Creating fund allocation 6";
    my $allocation6 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 3,
            sub_fund_id => undef,
            ledger_id => 4,
            fiscal_yr_id => 3,
            allocation_amount => 1200,
            reference => 'Ref1',
            note => 'Note text',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 7";
    my $allocation7 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 3,
            sub_fund_id => undef,
            ledger_id => 4,
            fiscal_yr_id => 3,
            allocation_amount => 50,
            reference => 'Ref2',
            note => 'Note text',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 8";
    my $allocation8 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 4,
            sub_fund_id => undef,
            ledger_id => 2,
            fiscal_yr_id => 1,
            allocation_amount => 500,
            reference => 'Ref1',
            note => 'Set up',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();
    warn "Creating fund allocation 9";
    my $allocation9 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 5,
            sub_fund_id => undef,
            ledger_id => 5,
            fiscal_yr_id => 2,
            allocation_amount => 5000,
            reference => 'Ref1',
            note => 'Lots of money',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 10";
    my $allocation10 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 5,
            sub_fund_id => undef,
            ledger_id => 5,
            fiscal_yr_id => 2,
            allocation_amount => 1000,
            reference => 'Ref2',
            note => 'Even more money',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 11";
    my $allocation11 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 6,
            sub_fund_id => undef,
            ledger_id => 1,
            fiscal_yr_id => 1,
            allocation_amount => 1000,
            reference => 'Ref1',
            note => 'Funds',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 12";
    my $allocation12 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 6,
            sub_fund_id => undef,
            ledger_id => 1,
            fiscal_yr_id => 1,
            allocation_amount => 250,
            reference => 'Ref2',
            note => 'More funds',
            currency => 'GBP',
            owner => 51,
            visible_to => '11'
        }
    )->store();
    warn "Creating fund allocation 13";
    my $allocation13 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 7,
            sub_fund_id => undef,
            ledger_id => 3,
            fiscal_yr_id => 1,
            allocation_amount => 250,
            reference => 'Ref1',
            note => 'Adding money',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();
    warn "Creating fund allocation 14";
    my $allocation14 = Koha::Acquire::Funds::FundAllocation->new(
        {
            fund_id => 7,
            sub_fund_id => undef,
            ledger_id => 3,
            fiscal_yr_id => 1,
            allocation_amount => 25,
            reference => 'Ref2',
            note => 'Adding more money',
            currency => 'GBP',
            owner => 51,
            visible_to => '1'
        }
    )->store();

    warn "Fund allocations complete";
}

# Helper methods

sub _get_patrons_to_load {
    my ($branchcode) = @_;

    my $patrons_to_load = {
        all => {
            details => {
                userid     => "$branchcode" . "all",
                firstname  => $branchcode,
                surname    => 'All_Permissions',
                flags      => 2052,
                branchcode => $branchcode
            },
        },
        manage_budgets => {
            details => {
                userid     => "$branchcode" . "manage_budgets",
                firstname  => $branchcode,
                surname    => 'Manage_Budgets',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 0,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 0,
                'period_manage'     => 1,
                'planning_manage'   => 1,
            }
        },
        manage_funds => {
            details => {
                userid     => "$branchcode" . "manage_funds",
                firstname  => $branchcode,
                surname    => 'Manage_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 1,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 1,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        },
        add_funds => {
            details => {
                userid     => "$branchcode" . "add_funds",
                firstname  => $branchcode,
                surname    => 'Add_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 1,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 0,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        },
        edit_funds => {
            details => {
                userid     => "$branchcode" . "edit_funds",
                firstname  => $branchcode,
                surname    => 'Edit_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 0,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 1,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        }
    };

    my $generic_fields = {
        dateofbirth              => "1990-01-01",
        middle_name              => '',
        othernames               => '',
        categorycode             => 'S',
        dateexpiry               => '2030-04-01',
        password_expiration_date => '2025-01-01',
        lost                     => 0,
        debarred                 => undef,
    };

    foreach my $key ( keys %$patrons_to_load ) {
        my $patron_details = $patrons_to_load->{$key}->{details};
        foreach my $generic_field ( keys %$generic_fields ) {
            $patron_details->{$generic_field} = $generic_fields->{$generic_field};
        }
    }

    return $patrons_to_load;
}

sub clear_plugin_data {
    my $data_query = "DELETE FROM plugin_data";
    my $methods_query = "DELETE FROM plugin_methods";

    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare($data_query);
    $sth->execute();
    my $sth2 = $dbh->prepare($methods_query);
    $sth2->execute();
}

