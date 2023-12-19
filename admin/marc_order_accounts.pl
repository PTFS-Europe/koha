#!/usr/bin/perl

# A script that allows the user to create an account and profile for auto-creating orders from imported marc files
# The script displays account details and allows account creation/editing in the first instance
# If the "run" operation is passed then the script will run the process of creating orders

# Copyright 2023 PTFS Europe Ltd
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

use Modern::Perl;
use CGI qw ( -utf8 );

use C4::Context;
use C4::Auth qw( get_template_and_user );
use C4::Budgets qw( GetBudgets );
use C4::Output qw( output_html_with_http_headers );
use C4::Matcher;

use Koha::UploadedFiles;
use Koha::ImportBatchProfiles;
use Koha::MarcOrder;
use Koha::Acquisition::Booksellers;
use Koha::MarcOrderAccount;
use Koha::MarcOrderAccounts;

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "admin/marc_order_accounts.tt",
        query           => $input,
        type            => "intranet",
    }
);

my $crypt = Koha::Encryption->new;

my $op = $input->param('op');
$op ||= 'display';

if( $op eq 'acct_form') {
    $template->param( acct_form => 1 );
    my @vendors = Koha::Acquisition::Booksellers->search(
        undef,
        {
            columns => [ 'name', 'id' ],
            order_by => { -asc => 'name' }
        }
    )->as_list;
    my $budgets = GetBudgets();
    $template->param(
        vendors => \@vendors,
        budgets => $budgets
    );
    my @matchers = C4::Matcher::GetMatcherList();
    $template->param( available_matchers => \@matchers );

    show_account($input, $template);
} elsif ( $op eq 'delete_acct' ) {
    show_account($input, $template);
    $template->param( delete_acct => 1);
} else {
    if( $op eq 'save' ) {

        my $fields = {
            id                 => scalar $input->param('id'),
            description        => scalar $input->param('description'),
            vendor_id          => scalar $input->param('vendor_id'),
            budget_id          => scalar $input->param('budget_id'),
            download_directory => scalar $input->param('download_directory'),
            matcher_id         => scalar $input->param('matcher'),
            overlay_action     => scalar $input->param('overlay_action'),
            nomatch_action     => scalar $input->param('nomatch_action'),
            parse_items        => scalar $input->param('parse_items'),
            item_action        => scalar $input->param('item_action'),
            record_type        => scalar $input->param('record_type'),
            encoding           => scalar $input->param('encoding') || 'UTF-8',
            match_field        => scalar $input->param('match_field'),
            match_value        => scalar $input->param('match_value'),
        };

        if(scalar $input->param('id')) {
            # Update existing account
            my $account = Koha::MarcOrderAccounts->find(scalar $input->param('id'));
            $account->update($fields);
        } else {
            # Add new account
            my $new_account = Koha::MarcOrderAccount->new($fields);
            $new_account->store;
        }
    } elsif ($op eq 'delete_confirmed') {
        my $acct_id = $input->param('id');
        my $acct = Koha::MarcOrderAccounts->find($acct_id);
        $acct->delete;
    }

    $template->param( display => 1 );
    my @accounts = Koha::MarcOrderAccounts->search(
        {},
        {
            join => ['vendor', 'budget']
        }
    )->as_list;
    $template->param( accounts => \@accounts );

}

output_html_with_http_headers $input, $cookie, $template->output;

sub show_account {
    my ($input, $template) = @_;
    my $acct_id = $input->param('id');
    if ($acct_id) {
        my $acct = Koha::MarcOrderAccounts->find($acct_id);
        if ($acct) {
            $template->param( account => $acct );
        }
    }
    return;
}