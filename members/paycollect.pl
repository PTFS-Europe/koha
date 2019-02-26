#!/usr/bin/perl
# Copyright 2009,2010 PTFS Inc.
# Copyright 2011 PTFS-Europe Ltd
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
use URI::Escape;
use CGI qw ( -utf8 );

use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::Accounts;
use C4::Koha;

use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::AuthorisedValues;
use Koha::Account;
use Koha::Token;

my $input = CGI->new();

my $updatecharges_permissions = $input->param('writeoff_individual') ? 'writeoff' : 'remaining_permissions';
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => 'members/paycollect.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 'edit_borrowers', updatecharges => $updatecharges_permissions },
        debug           => 1,
    }
);

# get borrower details
my $borrowernumber = $input->param('borrowernumber');
my $logged_in_user = Koha::Patrons->find( $loggedinuser ) or die "Not logged in";
my $patron         = Koha::Patrons->find( $borrowernumber );
output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

my $borrower       = $patron->unblessed;
my $category       = $patron->category;
my $user           = $input->remote_user;

my $branch    = C4::Context->userenv->{'branch'};
my $total_due = $patron->account->outstanding_debits->total_outstanding;

my $total_paid = $input->param('paid');

my $individual   = $input->param('pay_individual');
my $writeoff     = $input->param('writeoff_individual');
my $select_lines = $input->param('selected');
my $select       = $input->param('selected_accts');
my $payment_note = uri_unescape scalar $input->param('payment_note');
my $payment_type = scalar $input->param('payment_type');
my $type         = scalar $input->param('type') || 'payment',
my $accountlines_id;

if ( $individual || $writeoff ) {
    if ($individual) {
        $template->param( pay_individual => 1 );
    } elsif ($writeoff) {
        $template->param( writeoff_individual => 1 );
    }
    my $accounttype       = $input->param('accounttype');
    $accountlines_id       = $input->param('accountlines_id');
    my $amount            = $input->param('amount');
    my $amountoutstanding = $input->param('amountoutstanding');
    my $itemnumber  = $input->param('itemnumber');
    my $description  = $input->param('description');
    my $title        = $input->param('title');
    $total_due = $amountoutstanding;
    $template->param(
        accounttype       => $accounttype,
        accountlines_id    => $accountlines_id,
        amount            => $amount,
        amountoutstanding => $amountoutstanding,
        title             => $title,
        itemnumber        => $itemnumber,
        individual_description => $description,
        payment_note    => $payment_note,
    );
} elsif ($select_lines) {
    $total_due = $input->param('amt');
    $template->param(
        selected_accts => $select_lines,
        amt            => $total_due,
        selected_accts_notes => scalar $input->param('notes'),
    );
}

if ( $total_paid and $total_paid ne '0.00' ) {
    if ( $total_paid < 0 or $total_paid > $total_due ) {
        $template->param(
            error_over => 1,
            total_due => $total_due
        );
    } else {
        output_and_exit( $input, $cookie, $template,  'wrong_csrf_token' )
            unless Koha::Token->new->check_csrf( {
                session_id => $input->cookie('CGISESSID'),
                token  => scalar $input->param('csrf_token'),
            });

        if ($individual) {
            my $line = Koha::Account::Lines->find($accountlines_id);
            Koha::Account->new( { patron_id => $borrowernumber } )->pay(
                {
                    lines        => [$line],
                    amount       => $total_paid,
                    library_id   => $branch,
                    note         => $payment_note,
                    payment_type => $payment_type,
                }
            );
            print $input->redirect(
                "/cgi-bin/koha/members/pay.pl?borrowernumber=$borrowernumber");
        } else {
            if ($select) {
                if ( $select =~ /^([\d,]*).*/ ) {
                    $select = $1;    # ensure passing no junk
                }
                my @acc = split /,/, $select;
                my $note = $input->param('selected_accts_notes');

                my @lines = Koha::Account::Lines->search(
                    {
                        borrowernumber    => $borrowernumber,
                        amountoutstanding => { '<>' => 0 },
                        accountlines_id   => { 'IN' => \@acc },
                    },
                    { order_by => 'date' }
                );

                Koha::Account->new(
                    {
                        patron_id => $borrowernumber,
                    }
                  )->pay(
                    {
                        type         => $type,
                        amount       => $total_paid,
                        lines        => \@lines,
                        note         => $note,
                        payment_type => $payment_type,
                    }
                  );
            }
            else {
                my $note = $input->param('selected_accts_notes');
                Koha::Account->new( { patron_id => $borrowernumber } )->pay(
                    {
                        amount       => $total_paid,
                        note         => $note,
                        payment_type => $payment_type,
                    }
                );
            }

            print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
        }
    }
} else {
    $total_paid = '0.00';    #TODO not right with pay_individual
}

borrower_add_additional_fields($patron, $template);

$template->param(%$borrower);

if ( $input->param('error_over') ) {
    $template->param( error_over => 1, total_due => scalar $input->param('amountoutstanding') );
}

$template->param(
    type           => $type,
    borrowernumber => $borrowernumber,    # some templates require global
    patron        => $patron,
    total         => $total_due,
    ExtendedPatronAttributes => C4::Context->preference('ExtendedPatronAttributes'),

    csrf_token => Koha::Token->new->generate_csrf({ session_id => scalar $input->cookie('CGISESSID') }),
);

output_html_with_http_headers $input, $cookie, $template->output;

sub borrower_add_additional_fields {
    my ( $patron, $template ) = @_;

# some borrower info is not returned in the standard call despite being assumed
# in a number of templates. It should not be the business of this script but in lieu of
# a revised api here it is ...

    if (C4::Context->preference('ExtendedPatronAttributes')) {
        my $extendedattributes = GetBorrowerAttributes($patron->borrowernumber);
        $template->param( extendedattributes => $extendedattributes );
    }

    return;
}
