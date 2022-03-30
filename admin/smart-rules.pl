#!/usr/bin/perl
# Copyright 2000-2002 Katipo Communications
# copyright 2010 BibLibre
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
use C4::Output qw( output_html_with_http_headers );
use C4::Auth qw( get_template_and_user );
use Koha::Exception;
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Database;
use Koha::Logger;
use Koha::Libraries;
use Koha::CirculationRules;
use Koha::Patron::Categories;
use Koha::Caches;
use Koha::Patrons;

my $input = CGI->new;
my $dbh = C4::Context->dbh;

# my $flagsrequired;
# $flagsrequired->{circulation}=1;
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "admin/smart-rules.tt",
                            query => $input,
                            type => "intranet",
                            flagsrequired => {parameters => 'manage_circ_rules'},
                            });

my $type=$input->param('type');

my $branch = $input->param('branch');
unless ( $branch ) {
    if ( C4::Context->preference('DefaultToLoggedInLibraryCircRules') ) {
        $branch = Koha::Libraries->search->count() == 1 ? undef : C4::Context::mybranch();
    }
    else {
        $branch = C4::Context::only_my_library() ? ( C4::Context::mybranch() || '*' ) : '*';
    }
}

my $logged_in_patron = Koha::Patrons->find( $loggedinuser );

my $can_edit_from_any_library = $logged_in_patron->has_permission( {parameters => 'manage_circ_rules_from_any_libraries' } );
$template->param( restricted_to_own_library => not $can_edit_from_any_library );
$branch = C4::Context::mybranch() unless $can_edit_from_any_library;

my $op = $input->param('op') || q{};
my $language = C4::Languages::getlanguage();

my $cache = Koha::Caches->get_instance;
$cache->clear_from_cache( Koha::CirculationRules::GUESSED_ITEMTYPES_KEY );

if ($op eq 'delete') {
    my $itemtype     = $input->param('itemtype');
    my $categorycode = $input->param('categorycode');

    Koha::CirculationRules->set_rules(
        {
            categorycode => $categorycode eq '*' ? undef : $categorycode,
            branchcode   => $branch eq '*' ? undef : $branch,
            itemtype     => $itemtype eq '*' ? undef : $itemtype,
            rules        => {
                maxissueqty                      => undef,
                maxonsiteissueqty                => undef,
                rentaldiscount                   => undef,
                fine                             => undef,
                finedays                         => undef,
                maxsuspensiondays                => undef,
                suspension_chargeperiod          => undef,
                firstremind                      => undef,
                chargeperiod                     => undef,
                chargeperiod_charge_at           => undef,
                issuelength                      => undef,
                daysmode                         => undef,
                lengthunit                       => undef,
                hardduedate                      => undef,
                hardduedatecompare               => undef,
                renewalsallowed                  => undef,
                unseen_renewals_allowed          => undef,
                renewalperiod                    => undef,
                norenewalbefore                  => undef,
                auto_renew                       => undef,
                no_auto_renewal_after            => undef,
                no_auto_renewal_after_hard_limit => undef,
                reservesallowed                  => undef,
                holds_per_record                 => undef,
                holds_per_day                    => undef,
                onshelfholds                     => undef,
                opacitemholds                    => undef,
                overduefinescap                  => undef,
                cap_fine_to_replacement_price    => undef,
                article_requests                 => undef,
                note                             => undef,
                recalls_allowed                  => undef,
                recalls_per_record               => undef,
                on_shelf_recalls                 => undef,
                recall_due_date_interval         => undef,
                recall_overdue_fine              => undef,
                recall_shelf_time                => undef,
            }
        }
    );
}
elsif ($op eq 'delete-branch-cat') {
    my $categorycode  = $input->param('categorycode');
    if ($branch eq "*") {
        if ($categorycode eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    branchcode   => undef,
                    categorycode => undef,
                    rules        => {
                        max_holds                      => undef,
                        patron_maxissueqty             => undef,
                        patron_maxonsiteissueqty       => undef,
                    }
                }
            );
            Koha::CirculationRules->set_rules(
                {
                    branchcode   => undef,
                    itemtype     => undef,
                    rules        => {
                        holdallowed             => undef,
                        hold_fulfillment_policy => undef,
                        returnbranch            => undef,
                    }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => $categorycode,
                    branchcode   => undef,
                    rules        => {
                        max_holds                => undef,
                        patron_maxissueqty       => undef,
                        patron_maxonsiteissueqty => undef,
                    }
                }
            );
        }
    } elsif ($categorycode eq "*") {
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $branch,
                categorycode => undef,
                rules        => {
                    max_holds                => undef,
                    patron_maxissueqty       => undef,
                    patron_maxonsiteissueqty => undef,
                }
            }
        );
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $branch,
                itemtype     => undef,
                rules        => {
                    holdallowed             => undef,
                    hold_fulfillment_policy => undef,
                    returnbranch            => undef,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                categorycode => $categorycode,
                branchcode   => $branch,
                rules        => {
                    max_holds         => undef,
                    patron_maxissueqty       => undef,
                    patron_maxonsiteissueqty => undef,
                }
            }
        );
    }
}
elsif ($op eq 'delete-branch-item') {
    my $itemtype  = $input->param('itemtype');
    if ($branch eq "*") {
        if ($itemtype eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    branchcode   => undef,
                    itemtype     => undef,
                    rules        => {
                        holdallowed             => undef,
                        hold_fulfillment_policy => undef,
                        returnbranch            => undef,
                    }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {
                    branchcode   => undef,
                    itemtype     => $itemtype,
                    rules        => {
                        holdallowed             => undef,
                        hold_fulfillment_policy => undef,
                        returnbranch            => undef,
                    }
                }
            );
        }
    } elsif ($itemtype eq "*") {
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $branch,
                itemtype     => undef,
                rules        => {
                    holdallowed             => undef,
                    hold_fulfillment_policy => undef,
                    returnbranch            => undef,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $branch,
                itemtype     => $itemtype,
                rules        => {
                    holdallowed             => undef,
                    hold_fulfillment_policy => undef,
                    returnbranch            => undef,
                }
            }
        );
    }
}
# save the values entered
elsif ($op eq 'add') {
    my $br = $branch; # branch
    my $bor  = $input->param('categorycode'); # borrower category
    my $itemtype  = $input->param('itemtype');     # item type
    my $fine = $input->param('fine');
    my $finedays     = $input->param('finedays');
    my $maxsuspensiondays = $input->param('maxsuspensiondays') || '';
    my $suspension_chargeperiod = $input->param('suspension_chargeperiod') || 1;
    my $firstremind  = $input->param('firstremind');
    my $chargeperiod = $input->param('chargeperiod');
    my $chargeperiod_charge_at = $input->param('chargeperiod_charge_at');
    my $maxissueqty = strip_non_numeric( scalar $input->param('maxissueqty') );
    my $maxonsiteissueqty = strip_non_numeric( scalar $input->param('maxonsiteissueqty') );
    my $renewalsallowed  = $input->param('renewalsallowed');
    my $unseen_renewals_allowed  = $input->param('unseen_renewals_allowed');
    my $renewalperiod    = $input->param('renewalperiod');
    my $norenewalbefore  = $input->param('norenewalbefore');
    $norenewalbefore = '' if $norenewalbefore =~ /^\s*$/;
    my $auto_renew = $input->param('auto_renew') eq 'yes' ? 1 : 0;
    my $no_auto_renewal_after = $input->param('no_auto_renewal_after');
    $no_auto_renewal_after = '' if $no_auto_renewal_after =~ /^\s*$/;
    my $no_auto_renewal_after_hard_limit = $input->param('no_auto_renewal_after_hard_limit') || '';
    $no_auto_renewal_after_hard_limit = eval { dt_from_string( scalar $no_auto_renewal_after_hard_limit ) } if ( $no_auto_renewal_after_hard_limit );
    $no_auto_renewal_after_hard_limit = output_pref( { dt => $no_auto_renewal_after_hard_limit, dateonly => 1, dateformat => 'iso' } ) if ( $no_auto_renewal_after_hard_limit );
    my $reservesallowed  = strip_non_numeric( scalar $input->param('reservesallowed') );
    my $holds_per_record = strip_non_numeric( scalar $input->param('holds_per_record') );
    my $holds_per_day    = strip_non_numeric( scalar $input->param('holds_per_day') );
    my $onshelfholds     = $input->param('onshelfholds') || 0;
    my $issuelength  = $input->param('issuelength');
    $issuelength = $issuelength eq q{} ? undef : $issuelength;
    my $daysmode = $input->param('daysmode');
    my $lengthunit  = $input->param('lengthunit');
    my $hardduedate = $input->param('hardduedate') || undef;
    $hardduedate = eval { dt_from_string( scalar $hardduedate ) } if ( $hardduedate );
    $hardduedate = output_pref( { dt => $hardduedate, dateonly => 1, dateformat => 'iso' } ) if ( $hardduedate );
    my $hardduedatecompare = $input->param('hardduedatecompare');
    my $rentaldiscount = $input->param('rentaldiscount');
    my $opacitemholds = $input->param('opacitemholds') || 0;
    my $article_requests = $input->param('article_requests') || 'no';
    my $overduefinescap = $input->param('overduefinescap') || '';
    my $cap_fine_to_replacement_price = ($input->param('cap_fine_to_replacement_price') || '') eq 'on';
    my $note = $input->param('note');
    my $decreaseloanholds = $input->param('decreaseloanholds') || undef;
    my $recalls_allowed = $input->param('recalls_allowed');
    my $recalls_per_record = $input->param('recalls_per_record');
    my $on_shelf_recalls = $input->param('on_shelf_recalls');
    my $recall_due_date_interval = $input->param('recall_due_date_interval');
    my $recall_overdue_fine = $input->param('recall_overdue_fine');
    my $recall_shelf_time = $input->param('recall_shelf_time');

    my $rules = {
        maxissueqty                   => $maxissueqty,
        maxonsiteissueqty             => $maxonsiteissueqty,
        rentaldiscount                => $rentaldiscount,
        fine                          => $fine,
        finedays                      => $finedays,
        maxsuspensiondays             => $maxsuspensiondays,
        suspension_chargeperiod       => $suspension_chargeperiod,
        firstremind                   => $firstremind,
        chargeperiod                  => $chargeperiod,
        chargeperiod_charge_at        => $chargeperiod_charge_at,
        issuelength                   => $issuelength,
        daysmode                      => $daysmode,
        lengthunit                    => $lengthunit,
        hardduedate                   => $hardduedate,
        hardduedatecompare            => $hardduedatecompare,
        renewalsallowed               => $renewalsallowed,
        unseen_renewals_allowed       => $unseen_renewals_allowed,
        renewalperiod                 => $renewalperiod,
        norenewalbefore               => $norenewalbefore,
        auto_renew                    => $auto_renew,
        no_auto_renewal_after         => $no_auto_renewal_after,
        no_auto_renewal_after_hard_limit => $no_auto_renewal_after_hard_limit,
        reservesallowed               => $reservesallowed,
        holds_per_record              => $holds_per_record,
        holds_per_day                 => $holds_per_day,
        onshelfholds                  => $onshelfholds,
        opacitemholds                 => $opacitemholds,
        overduefinescap               => $overduefinescap,
        cap_fine_to_replacement_price => $cap_fine_to_replacement_price,
        article_requests              => $article_requests,
        note                          => $note,
        decreaseloanholds             => $decreaseloanholds,
        recalls_allowed               => $recalls_allowed,
        recalls_per_record            => $recalls_per_record,
        on_shelf_recalls              => $on_shelf_recalls,
        recall_due_date_interval      => $recall_due_date_interval,
        recall_overdue_fine           => $recall_overdue_fine,
        recall_shelf_time             => $recall_shelf_time,
    };

    Koha::CirculationRules->set_rules(
        {
            categorycode => $bor eq '*' ? undef : $bor,
            itemtype     => $itemtype eq '*' ? undef : $itemtype,
            branchcode   => $br eq '*' ? undef : $br,
            rules        => $rules,
        }
    );

}
elsif ($op eq "set-branch-defaults") {
    my $categorycode  = $input->param('categorycode');
    my $patron_maxissueqty = strip_non_numeric( scalar $input->param('patron_maxissueqty') );
    my $patron_maxonsiteissueqty = $input->param('patron_maxonsiteissueqty');
    $patron_maxonsiteissueqty = strip_non_numeric($patron_maxonsiteissueqty);
    my $holdallowed   = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch  = $input->param('returnbranch');
    my $max_holds = strip_non_numeric( scalar $input->param('max_holds') );

    if ($branch eq "*") {
        Koha::CirculationRules->set_rules(
            {
                itemtype     => undef,
                branchcode   => undef,
                rules        => {
                    holdallowed             => $holdallowed,
                    hold_fulfillment_policy => $hold_fulfillment_policy,
                    returnbranch            => $returnbranch,
                }
            }
        );
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                branchcode   => undef,
                rules        => {
                    patron_maxissueqty             => $patron_maxissueqty,
                    patron_maxonsiteissueqty       => $patron_maxonsiteissueqty,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                itemtype     => undef,
                branchcode   => $branch,
                rules        => {
                    holdallowed             => $holdallowed,
                    hold_fulfillment_policy => $hold_fulfillment_policy,
                    returnbranch            => $returnbranch,
                }
            }
        );
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                branchcode   => $branch,
                rules        => {
                    patron_maxissueqty             => $patron_maxissueqty,
                    patron_maxonsiteissueqty       => $patron_maxonsiteissueqty,
                }
            }
        );
    }
    Koha::CirculationRules->set_rule(
        {
            branchcode   => $branch,
            categorycode => undef,
            rule_name    => 'max_holds',
            rule_value   => $max_holds,
        }
    );
}
elsif ($op eq "add-branch-cat") {
    my $categorycode  = $input->param('categorycode');
    my $patron_maxissueqty = strip_non_numeric( scalar $input->param('patron_maxissueqty') );
    my $patron_maxonsiteissueqty = $input->param('patron_maxonsiteissueqty');
    $patron_maxonsiteissueqty = strip_non_numeric($patron_maxonsiteissueqty);
    my $max_holds = $input->param('max_holds');
    $max_holds =~ s/\s//g;
    $max_holds = undef if $max_holds !~ /^\d+/;

    if ($branch eq "*") {
        if ($categorycode eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => undef,
                    branchcode   => undef,
                    rules        => {
                        max_holds         => $max_holds,
                        patron_maxissueqty       => $patron_maxissueqty,
                        patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                    }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => $categorycode,
                    branchcode   => undef,
                    rules        => {
                        max_holds         => $max_holds,
                        patron_maxissueqty       => $patron_maxissueqty,
                        patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                    }
                }
            );
        }
    } elsif ($categorycode eq "*") {
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                branchcode   => $branch,
                rules        => {
                    max_holds         => $max_holds,
                    patron_maxissueqty       => $patron_maxissueqty,
                    patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                categorycode => $categorycode,
                branchcode   => $branch,
                rules        => {
                    max_holds         => $max_holds,
                    patron_maxissueqty       => $patron_maxissueqty,
                    patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                }
            }
        );
    }
}
elsif ( $op eq "add-open-article-requests-limit" ) {
    my $categorycode                = $input->param('categorycode');
    my $open_article_requests_limit = strip_non_numeric( scalar $input->param('open_article_requests_limit') );

    Koha::Exception->throw("No value passed for article request limit")
      if not defined $open_article_requests_limit # There is a JS check for that
      || $open_article_requests_limit eq '';

    if ( $branch eq "*" ) {
        if ( $categorycode eq "*" ) {
            Koha::CirculationRules->set_rules(
                {   categorycode => undef,
                    branchcode   => undef,
                    rules        => { open_article_requests_limit => $open_article_requests_limit, }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {   categorycode => $categorycode,
                    branchcode   => undef,
                    rules        => { open_article_requests_limit => $open_article_requests_limit, }
                }
            );
        }
    } elsif ( $categorycode eq "*" ) {
        Koha::CirculationRules->set_rules(
            {   categorycode => undef,
                branchcode   => $branch,
                rules        => { open_article_requests_limit => $open_article_requests_limit, }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {   categorycode => $categorycode,
                branchcode   => $branch,
                rules        => { open_article_requests_limit => $open_article_requests_limit, }
            }
        );
    }
} elsif ( $op eq 'del-open-article-requests-limit' ) {
    my $categorycode = $input->param('categorycode');
    if ( $branch eq "*" ) {
        if ( $categorycode eq "*" ) {
            Koha::CirculationRules->set_rules(
                {   branchcode   => undef,
                    categorycode => undef,
                    rules        => { open_article_requests_limit => undef, }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {   categorycode => $categorycode,
                    branchcode   => undef,
                    rules        => { open_article_requests_limit => undef, }
                }
            );
        }
    } elsif ( $categorycode eq "*" ) {
        Koha::CirculationRules->set_rules(
            {   branchcode   => $branch,
                categorycode => undef,
                rules        => { open_article_requests_limit => undef, }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {   categorycode => $categorycode,
                branchcode   => $branch,
                rules        => { open_article_requests_limit => undef, }
            }
        );
    }
}
elsif ( $op eq "set-article-request-fee" ) {

    my $category = $input->param('article_request_fee_category');
    my $fee      = strip_non_numeric( scalar $input->param('article_request_fee') );

    Koha::Exception->throw("No value passed for article request fee")
      if not defined $fee # There is a JS check for that
      || $fee eq '';

    Koha::CirculationRules->set_rules(
        {   categorycode => ( $category  eq '*' ) ? undef : $category,
            branchcode   => ( $branch    eq '*' ) ? undef : $branch,
            rules        => { article_request_fee => $fee },
        }
    );

} elsif ( $op eq 'del-article-request-fee' ) {

    my $category  = $input->param('article_request_fee_category');

    Koha::CirculationRules->set_rules(
        {   categorycode => ( $category eq  '*' ) ? undef : $category,
            branchcode   => ( $branch eq    '*' ) ? undef : $branch,
            rules        => { article_request_fee => undef },
        }
    );
}
elsif ($op eq "add-branch-item") {
    my $itemtype                = $input->param('itemtype');
    my $holdallowed             = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch            = $input->param('returnbranch');

    if ($branch eq "*") {
        if ($itemtype eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    itemtype     => undef,
                    branchcode   => undef,
                    rules        => {
                        holdallowed             => $holdallowed,
                        hold_fulfillment_policy => $hold_fulfillment_policy,
                        returnbranch            => $returnbranch,
                    }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {
                    itemtype     => $itemtype,
                    branchcode   => undef,
                    rules        => {
                        holdallowed             => $holdallowed,
                        hold_fulfillment_policy => $hold_fulfillment_policy,
                        returnbranch            => $returnbranch,
                    }
                }
            );
        }
    } elsif ($itemtype eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    itemtype     => undef,
                    branchcode   => $branch,
                    rules        => {
                        holdallowed             => $holdallowed,
                        hold_fulfillment_policy => $hold_fulfillment_policy,
                        returnbranch            => $returnbranch,
                    }
                }
            );
    } else {
        Koha::CirculationRules->set_rules(
            {
                itemtype     => $itemtype,
                branchcode   => $branch,
                rules        => {
                    holdallowed             => $holdallowed,
                    hold_fulfillment_policy => $hold_fulfillment_policy,
                    returnbranch            => $returnbranch,
                }
            }
        );
    }
}
elsif ( $op eq 'mod-refund-lost-item-fee-rule' ) {

    my $lostreturn = $input->param('lostreturn');

    if ( $lostreturn eq '*' ) {
        if ( $branch ne '*' ) {
            # only do something for $lostreturn eq '*' if branch-specific
            Koha::CirculationRules->set_rules(
                {
                    branchcode   => $branch,
                    rules        => {
                        lostreturn => undef
                    }
                }
            );
        }
    } else {
        Koha::CirculationRules->set_rules(
            {
                branchcode   => $branch,
                rules        => {
                    lostreturn => $lostreturn
                }
            }
        );
    }
}

my $refundLostItemFeeRule = Koha::CirculationRules->find({ branchcode => ($branch eq '*') ? undef : $branch, rule_name => 'lostreturn' });
my $defaultLostItemFeeRule = Koha::CirculationRules->find({ branchcode => undef, rule_name => 'lostreturn' });
$template->param(
    refundLostItemFeeRule => $refundLostItemFeeRule,
    defaultRefundRule     => $defaultLostItemFeeRule ? $defaultLostItemFeeRule->rule_value : 'refund'
);

my $patron_categories = Koha::Patron::Categories->search({}, { order_by => ['description'] });

my $itemtypes = Koha::ItemTypes->search;

my $humanbranch = ( $branch ne '*' ? $branch : undef );

my $all_rules = Koha::CirculationRules->search({ branchcode => $humanbranch });
my $definedbranch = $all_rules->count ? 1 : 0;

my $rules = {};
while ( my $r = $all_rules->next ) {
    $r = $r->unblessed;
    $rules->{ $r->{categorycode} // '' }->{ $r->{itemtype} // '' }->{ $r->{rule_name} } = $r->{rule_value};
}

$template->param(show_branch_cat_rule_form => 1);

$template->param(
    patron_categories => $patron_categories,
    itemtypeloop      => $itemtypes,
    humanbranch       => $humanbranch,
    current_branch    => $branch,
    definedbranch     => $definedbranch,
    all_rules         => $rules,
);
output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

sub strip_non_numeric {
    my $string = shift;
    $string =~ s/\s//g;
    $string = '' if $string !~ /^\d+/;
    return $string;
}
