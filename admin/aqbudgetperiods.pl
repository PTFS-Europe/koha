#!/usr/bin/perl

# Copyright 2008 BibLibre, BibLibre, Paul POULAIN
#                SAN Ouest Provence
#
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 admin/aqbudgetperiods.pl

script to administer the budget periods table
 This software is placed under the gnu General Public License, v2 (http://www.gnu.org/licenses/gpl.html)

 ALGO :
 this script use an $op to know what to do.
 if $op is empty or none of the above values,
	- the default screen is build (with all records, or filtered datas).
	- the   user can clic on add, modify or delete record.
 if $op=add_form
	- if primkey exists, this is a modification,so we read the $primkey record
	- builds the add/modify form
 if $op=add_validate
	- the user has just send datas, so we create/modify the record
 if $op=delete_confirm
	- we show the record having primkey=$primkey and ask for deletion validation form
 if $op=delete_confirmed
	- we delete the record having primkey=$primkey
 if $op=duplicate_form
  - displays the duplication of budget period form (allowing specification of dates)
 if $op=duplicate_budget
  - we perform the duplication of the budget period specified as budget_period_id

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use List::Util qw/min/;
use Koha::DateUtils;
use Koha::Database;
use C4::Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Acquisition;
use C4::Budgets;
use C4::Debug;
use C4::Log qw(logaction);
use Koha::Acquisition::Currencies;

my $dbh = C4::Context->dbh;

my $input       = new CGI;

my $searchfield          = $input->param('searchfield') // '';
my $budget_period_id     = $input->param('budget_period_id');
my $op                   = $input->param('op')||"else";
#my $sort1_authcat = $input->param('sort1_authcat');
#my $sort2_authcat = $input->param('sort2_authcat');

# get only the columns of aqbudgetperiods in budget_period_hashref
my @columns = Koha::Database->new()->schema->source('Aqbudgetperiod')->columns;
my $budget_period_hashref = { map { join(' ',@columns) =~ /$_/ ? ( $_ => scalar $input->param($_) )  : () } keys( %{$input->Vars()} ) } ;
$budget_period_hashref->{budget_period_startdate} = dt_from_string( scalar $input->param('budget_period_startdate') );
$budget_period_hashref->{budget_period_enddate}   = dt_from_string( scalar $input->param('budget_period_enddate') );

$searchfield =~ s/\,//g;

my ($template, $borrowernumber, $cookie, $staff_flags ) = get_template_and_user(
    {
        template_name   => "admin/aqbudgetperiods.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { acquisition => 'period_manage' },
        debug           => 1,
    }
);


# This is used in incbudgets-active-currency.inc
my $active_currency = Koha::Acquisition::Currencies->get_active;
if ( $active_currency ) {
    $template->param( symbol => $active_currency->symbol,
                      currency => $active_currency->currency
                   );
}

# ADD OR MODIFY A BUDGET PERIOD - BUILD SCREEN
if ( $op eq 'add_form' ) {
    ## add or modify a budget period (preparation)
    ## get information about the budget period that must be modified

    if ($budget_period_id) {    # MOD
		my $budgetperiod_hash=GetBudgetPeriod($budget_period_id);
        # get dropboxes

        $template->param(
			%$budgetperiod_hash
        );
    } # IF-MOD
}

elsif ( $op eq 'add_validate' ) {
## add or modify a budget period (confirmation)

    ## update budget period data
    +    if ( $budget_period_id ne '' ) {
    +        # Grab the previous values so we can log them
        my $budgetperiod_old=GetBudgetPeriod($budget_period_id);
        $$budget_period_hashref{$_}||=0 for qw(budget_period_active budget_period_locked);
        my $status=ModBudgetPeriod($budget_period_hashref);
        # Log the budget modification
        if (C4::Context->preference("AcqLog")) {
            my $diff = 0 - ($budgetperiod_old->{budget_period_total} - $budget_period_hashref->{budget_period_total});
            my $infos =
                eval { output_pref({ dt => dt_from_string( $input->param('budget_period_startdate') ), dateformat => 'iso', dateonly => 1 } ); } .
                eval { output_pref({ dt => dt_from_string( $input->param('budget_period_enddate') ), dateformat => 'iso', dateonly => 1 } ); } .
                sprintf("%010d", $budget_period_hashref->{budget_period_total}) .
                eval { output_pref({ dt => dt_from_string( $budgetperiod_old->{budget_period_startdate} ), dateformat => 'iso', dateonly => 1 } ); } .
                eval { output_pref({ dt => dt_from_string( $budgetperiod_old->{budget_period_enddate} ), dateformat => 'iso', dateonly => 1 } ); } .
                sprintf("%010d", $budgetperiod_old->{budget_period_total}) .
                sprintf("%010d", $diff);
            logaction(
                'ACQUISITIONS',
                'MODIFY_BUDGET',
                $budget_period_id,
                $infos
            );
        }
    }
    else {    # ELSE ITS AN ADD
        my $budget_period_id=AddBudgetPeriod($budget_period_hashref);
    }
    $op='else';
}

#--------------------------------------------------
elsif ( $op eq 'delete_confirm' ) {
## delete a budget period (preparation)
    my $funds = GetBudgets({ budget_period_id => $budget_period_id });
    my $fund_count = scalar @$funds;
    if ( $fund_count > 0 ) {
        $template->param( funds_exist => 1 );
    }

    #$total = number of records linked to the record that must be deleted
    my $total = 0;
    my $data = GetBudgetPeriod( $budget_period_id);
    $template->param(
        %$data
    );
}

elsif ( $op eq 'delete_confirmed' ) {
    ## confirm no funds have been added to budget
    my $funds = GetBudgets({ budget_period_id => $budget_period_id });
    my $fund_count = scalar @$funds;
    if ( $fund_count > 0 ) {
        $template->param( failed_delete_funds_exist => 1 );
    } else {
        ## delete the budget period record
        my $data = GetBudgetPeriod( $budget_period_id);
        DelBudgetPeriod($budget_period_id);
    }
	$op='else';
}

# display the form for duplicating
elsif ( $op eq 'duplicate_form'){
    my $budgetperiod = GetBudgetPeriod($budget_period_id);
    $template->param(
        'duplicate_form' => '1',
        'budget_period_id' => $budget_period_id,
        'budgetperiod' => $budgetperiod,
    );
}

# handle the actual duplication
elsif ( $op eq 'duplicate_budget' ){
    die "please specify a budget period id\n" if( !defined $budget_period_id || $budget_period_id eq '' );

    my $budget_period_startdate = dt_from_string scalar $input->param('budget_period_startdate');
    my $budget_period_enddate   = dt_from_string scalar $input->param('budget_period_enddate');
    my $budget_period_description = $input->param('budget_period_description');
    my $amount_change_percentage = $input->param('amount_change_percentage');
    my $amount_change_round_increment = $input->param('amount_change_round_increment');
    my $mark_original_budget_as_inactive = $input->param('mark_original_budget_as_inactive');
    my $reset_all_budgets = $input->param('reset_all_budgets');

    my $new_budget_period_id = C4::Budgets::CloneBudgetPeriod(
        {
            budget_period_id        => $budget_period_id,
            budget_period_startdate => $budget_period_startdate,
            budget_period_enddate   => $budget_period_enddate,
            budget_period_description => $budget_period_description,
            amount_change_percentage => $amount_change_percentage,
            amount_change_round_increment => $amount_change_round_increment,
            mark_original_budget_as_inactive => $mark_original_budget_as_inactive,
            reset_all_budgets => $reset_all_budgets,
        }
    );

    # display the list of budgets
    $op = 'else';
}

elsif ( $op eq 'close_form' ) {

    my $budget_period = GetBudgetPeriod($budget_period_id);

    my $active_budget_periods =
      C4::Budgets::GetBudgetPeriods( { budget_period_active => 1 } );

    # Remove the budget period from the list
    $active_budget_periods =
      [ map { ( $_->{budget_period_id} == $budget_period_id ) ? () : $_ }
          @$active_budget_periods ];

    my $budgets_to_move = GetBudgetHierarchy($budget_period_id);

    my $number_of_unreceived_orders = 0;
    for my $budget (@$budgets_to_move) {

        # We want to move funds from this budget
        my $unreceived_orders = C4::Acquisition::SearchOrders(
            {
                budget_id => $budget->{budget_id},
                pending   => 1,
            }
        );
        $budget->{unreceived_orders} = $unreceived_orders;
        $number_of_unreceived_orders += scalar(@$unreceived_orders);
    }

    $template->param(
        close_form       => 1,
        budget_period_id => $budget_period_id,
        budget_period_description =>
          $budget_period->{budget_period_description},
        budget_periods              => $active_budget_periods,
        budgets_to_move             => $budgets_to_move,
        number_of_unreceived_orders => $number_of_unreceived_orders,
    );
}

elsif ( $op eq 'close_confirmed' ) {
    my $to_budget_period_id    = $input->param('to_budget_period_id');
    my $move_remaining_unspent = $input->param('move_remaining_unspent');
    my $report                 = C4::Budgets::MoveOrders(
        {
            from_budget_period_id  => $budget_period_id,
            to_budget_period_id    => $to_budget_period_id,
            move_remaining_unspent => $move_remaining_unspent,
        }
    );

    my $from_budget_period = GetBudgetPeriod($budget_period_id);
    my $to_budget_period   = GetBudgetPeriod($to_budget_period_id);
    $template->param(
        closed           => 1,
        budget_period_id => $from_budget_period->{budget_period_id},
        budget_period_description => $from_budget_period->{budget_period_description},
        from_budget_period => $from_budget_period,
        to_budget_period   => $to_budget_period,
        report             => $report,
    );
}

# DEFAULT - DISPLAY AQPERIODS TABLE
# -------------------------------------------------------------------
# display the list of budget periods

my $activepage = $input->param('apage') || 1;
my $inactivepage = $input->param('ipage') || 1;
# Get active budget periods
my $results = GetBudgetPeriods(
    { budget_period_active => 1 },
    { -asc => 'budget_period_description' },
);

my @period_active_loop;

foreach my $result ( @{$results} ) {
    my $budgetperiod = $result;
    $budgetperiod->{budget_active} = 1;
    my $funds = GetBudgets({ budget_period_id => $budgetperiod->{budget_period_id} });
    $budgetperiod->{count} = scalar @$funds;
    push( @period_active_loop, $budgetperiod );
}

# Get inactive budget periods
$results = GetBudgetPeriods(
    { budget_period_active => 0 },
    { -desc => 'budget_period_enddate' },
);

my @period_inactive_loop;
foreach my $result ( @{$results} ) {
    my $budgetperiod = $result;
    $budgetperiod->{budget_active} = 1;
    my $funds = GetBudgets({ budget_period_id => $budgetperiod->{budget_period_id} });
    $budgetperiod->{count} = scalar @$funds;
    push( @period_inactive_loop, $budgetperiod );
}

my $tab = $input->param('tab') ? $input->param('tab') - 1 : 0;
$template->param(
    period_active_loop      => \@period_active_loop,
    period_inactive_loop    => \@period_inactive_loop,
    tab                     => $tab,
);

$template->param($op=>1);
output_html_with_http_headers $input, $cookie, $template->output;
