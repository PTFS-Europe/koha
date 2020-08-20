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
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Debug;
use Koha::DateUtils;
use Koha::Database;
use Koha::IssuingRule;
use Koha::IssuingRules;
use Koha::Logger;
use Koha::RefundLostItemFeeRules;
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
                            authnotrequired => 0,
                            flagsrequired => {parameters => 'manage_circ_rules'},
                            debug => 1,
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

$branch = '*' if $branch eq 'NO_LIBRARY_SET';

my $op = $input->param('op') || q{};
my $language = C4::Languages::getlanguage();

my $cache = Koha::Caches->get_instance;
$cache->clear_from_cache( Koha::IssuingRules::GUESSED_ITEMTYPES_KEY );

if ($op eq 'delete') {
    my $itemtype     = $input->param('itemtype');
    my $categorycode = $input->param('categorycode');
    $debug and warn "deleting $1 $2 $branch";

    Koha::IssuingRules->find({
        branchcode   => $branch,
        categorycode => $categorycode,
        itemtype     => $itemtype
    })->delete;

}
elsif ($op eq 'delete-branch-cat') {
    my $categorycode  = $input->param('categorycode');
    if ($branch eq "*") {
        if ($categorycode eq "*") {
             Koha::CirculationRules->set_rules(
                 {
                     categorycode => undef,
                     branchcode   => undef,
                     itemtype     => undef,
                     rules        => {
                         patron_maxissueqty             => undef,
                         patron_maxonsiteissueqty       => undef,
                         holdallowed             => undef,
                         hold_fulfillment_policy => undef,
                         returnbranch            => undef,
                         max_holds               => undef,
                     }
                 }
             );
         } else {
             Koha::CirculationRules->set_rules(
                 {
                     categorycode => $categorycode,
                     branchcode   => undef,
                     itemtype     => undef,
                     rules        => {
                         max_holds         => undef,
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
                itemtype     => undef,
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
                    categorycode => undef,
                    branchcode   => undef,
                    itemtype     => undef,
                    rules        => {
                        patron_maxissueqty             => undef,
                        patron_maxonsiteissueqty       => undef,
                        holdallowed             => undef,
                        hold_fulfillment_policy => undef,
                        returnbranch            => undef,
                    }
                }
            );
        } else {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => undef,
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
                categorycode => undef,
                branchcode   => $branch,
                itemtype     => undef,
                rules        => {
                    maxissueqty             => undef,
                    maxonsiteissueqty       => undef,
                    holdallowed             => undef,
                    hold_fulfillment_policy => undef,
                    returnbranch            => undef,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
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
    my $maxsuspensiondays = $input->param('maxsuspensiondays');
    $maxsuspensiondays = undef if $maxsuspensiondays eq q||;
    my $suspension_chargeperiod = $input->param('suspension_chargeperiod') || 1;
    my $firstremind  = $input->param('firstremind');
    my $chargeperiod = $input->param('chargeperiod');
    my $chargeperiod_charge_at = $input->param('chargeperiod_charge_at');
    my $maxissueqty  = $input->param('maxissueqty');
    my $maxonsiteissueqty  = $input->param('maxonsiteissueqty');
    my $renewalsallowed  = $input->param('renewalsallowed');
    my $unseen_renewals_allowed  = $input->param('unseen_renewals_allowed');
    my $renewalperiod    = $input->param('renewalperiod');
    my $norenewalbefore  = $input->param('norenewalbefore');
    $norenewalbefore = undef if $norenewalbefore =~ /^\s*$/;
    my $auto_renew = $input->param('auto_renew') eq 'yes' ? 1 : 0;
    my $no_auto_renewal_after = $input->param('no_auto_renewal_after');
    $no_auto_renewal_after = undef if $no_auto_renewal_after =~ /^\s*$/;
    my $no_auto_renewal_after_hard_limit = $input->param('no_auto_renewal_after_hard_limit') || undef;
    $no_auto_renewal_after_hard_limit = eval { dt_from_string( $input->param('no_auto_renewal_after_hard_limit') ) } if ( $no_auto_renewal_after_hard_limit );
    $no_auto_renewal_after_hard_limit = output_pref( { dt => $no_auto_renewal_after_hard_limit, dateonly => 1, dateformat => 'iso' } ) if ( $no_auto_renewal_after_hard_limit );
    my $reservesallowed  = $input->param('reservesallowed');
    my $holds_per_record = $input->param('holds_per_record');
    my $holds_per_day    = $input->param('holds_per_day');
    $holds_per_day =~ s/\s//g;
    $holds_per_day = undef if $holds_per_day !~ /^\d+/;
    my $onshelfholds     = $input->param('onshelfholds') || 0;
    $maxissueqty =~ s/\s//g;
    $maxissueqty = '' if $maxissueqty !~ /^\d+/;
    $maxonsiteissueqty =~ s/\s//g;
    $maxonsiteissueqty = '' if $maxonsiteissueqty !~ /^\d+/;
    my $issuelength  = $input->param('issuelength');
    $issuelength = $issuelength eq q{} ? undef : $issuelength;
    my $lengthunit  = $input->param('lengthunit');
    my $hardduedate = $input->param('hardduedate') || undef;
    $hardduedate = eval { dt_from_string( $input->param('hardduedate') ) } if ( $hardduedate );
    $hardduedate = output_pref( { dt => $hardduedate, dateonly => 1, dateformat => 'iso' } ) if ( $hardduedate );
    my $hardduedatecompare = $input->param('hardduedatecompare');
    my $rentaldiscount = $input->param('rentaldiscount');
    my $opacitemholds = $input->param('opacitemholds') || 0;
    my $article_requests = $input->param('article_requests') || 'no';
    my $overduefinescap = $input->param('overduefinescap') || undef;
    my $cap_fine_to_replacement_price = $input->param('cap_fine_to_replacement_price') eq 'on';
    my $note = $input->param('note');
    $debug and warn "Adding $br, $bor, $itemtype, $fine, $maxissueqty, $maxonsiteissueqty, $cap_fine_to_replacement_price";

    my $params = {
        branchcode                    => $br,
        categorycode                  => $bor,
        itemtype                      => $itemtype,
        fine                          => $fine,
        finedays                      => $finedays,
        maxsuspensiondays             => $maxsuspensiondays,
        suspension_chargeperiod       => $suspension_chargeperiod,
        firstremind                   => $firstremind,
        chargeperiod                  => $chargeperiod,
        chargeperiod_charge_at        => $chargeperiod_charge_at,
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
        issuelength                   => $issuelength,
        lengthunit                    => $lengthunit,
        hardduedate                   => $hardduedate,
        hardduedatecompare            => $hardduedatecompare,
        rentaldiscount                => $rentaldiscount,
        onshelfholds                  => $onshelfholds,
        opacitemholds                 => $opacitemholds,
        overduefinescap               => $overduefinescap,
        cap_fine_to_replacement_price => $cap_fine_to_replacement_price,
        article_requests              => $article_requests,
        note                          => $note,
    };

    my $issuingrule = Koha::IssuingRules->find({categorycode => $bor, itemtype => $itemtype, branchcode => $br});
    if ($issuingrule) {
        $issuingrule->set($params)->store();
    } else {
        Koha::IssuingRule->new()->set($params)->store();
    }
    Koha::CirculationRules->set_rules(
        {
            categorycode => $bor,
            itemtype     => $itemtype,
            branchcode   => $br,
            rules        => {
                maxissueqty       => $maxissueqty,
                maxonsiteissueqty => $maxonsiteissueqty,
            }
        }
    );

}
elsif ($op eq "set-branch-defaults") {
    my $categorycode  = $input->param('categorycode');
    my $patron_maxissueqty   = $input->param('patron_maxissueqty');
    my $patron_maxonsiteissueqty = $input->param('patron_maxonsiteissueqty');
    my $holdallowed   = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch  = $input->param('returnbranch');
    my $max_holds = $input->param('max_holds');
    $patron_maxissueqty =~ s/\s//g;
    $patron_maxissueqty = '' if $patron_maxissueqty !~ /^\d+/;
    $patron_maxonsiteissueqty =~ s/\s//g;
    $patron_maxonsiteissueqty = '' if $patron_maxonsiteissueqty !~ /^\d+/;
    $holdallowed =~ s/\s//g;
    $holdallowed = undef if $holdallowed !~ /^\d+/;
    $max_holds =~ s/\s//g;
    $max_holds = '' if $max_holds !~ /^\d+/;

    if ($branch eq "*") {
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                itemtype     => undef,
                branchcode   => undef,
                rules        => {
                    patron_maxissueqty       => $patron_maxissueqty,
                    patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                    holdallowed              => $holdallowed,
                    hold_fulfillment_policy  => $hold_fulfillment_policy,
                    returnbranch             => $returnbranch,
                }
            }
        );
    } else {
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                itemtype     => undef,
                branchcode   => $branch,
                rules        => {
                    patron_maxissueqty       => $patron_maxissueqty,
                    patron_maxonsiteissueqty => $patron_maxonsiteissueqty,
                    holdallowed              => $holdallowed,
                    hold_fulfillment_policy  => $hold_fulfillment_policy,
                    returnbranch             => $returnbranch,
                }
            }
        );
    }
    Koha::CirculationRules->set_rule(
        {
            branchcode   => $branch,
            categorycode => undef,
            itemtype     => undef,
            rule_name    => 'max_holds',
            rule_value   => $max_holds,
        }
    );
}
elsif ($op eq "add-branch-cat") {
    my $categorycode  = $input->param('categorycode');
    my $patron_maxissueqty   = $input->param('patron_maxissueqty');
    my $patron_maxonsiteissueqty = $input->param('patron_maxonsiteissueqty');
    my $max_holds = $input->param('max_holds');
    $patron_maxissueqty =~ s/\s//g;
    $patron_maxissueqty = '' if $patron_maxissueqty !~ /^\d+/;
    $patron_maxonsiteissueqty =~ s/\s//g;
    $patron_maxonsiteissueqty = '' if $patron_maxonsiteissueqty !~ /^\d+/;
    $max_holds =~ s/\s//g;
    $max_holds = undef if $max_holds !~ /^\d+/;

    if ($branch eq "*") {
        if ($categorycode eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => undef,
                    itemtype     => undef,
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
                    branchcode   => undef,
                    categorycode => $categorycode,
                    itemtype     => undef,
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
                itemtype     => undef,
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
                itemtype     => undef,
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
elsif ($op eq "add-branch-item") {
    my $itemtype                = $input->param('itemtype');
    my $holdallowed             = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch            = $input->param('returnbranch');

    $holdallowed =~ s/\s//g;
    $holdallowed = undef if $holdallowed !~ /^\d+/;

    if ($branch eq "*") {
        if ($itemtype eq "*") {
            Koha::CirculationRules->set_rules(
                {
                    categorycode => undef,
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
                    categorycode => undef,
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
                    categorycode => undef,
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
                categorycode => undef,
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

    my $refund = $input->param('refund');

    if ( $refund eq '*' ) {
        if ( $branch ne '*' ) {
            # only do something for $refund eq '*' if branch-specific
            Koha::CirculationRules->set_rules(
                {
                    categorycode => undef,
                    itemtype     => undef,
                    branchcode   => $branch,
                    rules        => {
                        refund => undef
                    }
                }
            );
        }
    } else {
        Koha::CirculationRules->set_rules(
            {
                categorycode => undef,
                itemtype     => undef,
                branchcode   => $branch,
                rules        => {
                    refund => $refund
                }
            }
        );
    }
}

my $refundLostItemFeeRule = Koha::RefundLostItemFeeRules->find({ branchcode => ($branch eq '*') ? undef:$branch });

$template->param(
    refundLostItemFeeRule => $refundLostItemFeeRule,
    defaultRefundRule     => Koha::RefundLostItemFeeRules->_default_rule
);

my $patron_categories = Koha::Patron::Categories->search({}, { order_by => ['description'] });

my @row_loop;
my $itemtypes = Koha::ItemTypes->search_with_localization;

my $sth2 = $dbh->prepare("
    SELECT  issuingrules.*,
            itemtypes.description AS humanitemtype,
            categories.description AS humancategorycode,
            COALESCE( localization.translation, itemtypes.description ) AS translated_description
    FROM issuingrules
    LEFT JOIN itemtypes
        ON (itemtypes.itemtype = issuingrules.itemtype)
    LEFT JOIN categories
        ON (categories.categorycode = issuingrules.categorycode)
    LEFT JOIN localization ON issuingrules.itemtype = localization.code
        AND localization.entity = 'itemtypes'
        AND localization.lang = ?
    WHERE issuingrules.branchcode = ?
");
$sth2->execute($language, $branch);

while (my $row = $sth2->fetchrow_hashref) {
    $row->{'current_branch'} ||= $row->{'branchcode'};
    $row->{humanitemtype} ||= $row->{itemtype};
    $row->{default_translated_description} = 1 if $row->{humanitemtype} eq '*';
    $row->{'humancategorycode'} ||= $row->{'categorycode'};
    $row->{'default_humancategorycode'} = 1 if $row->{'humancategorycode'} eq '*';
    $row->{'fine'} = sprintf('%.2f', $row->{'fine'});
    if ($row->{'hardduedate'} && $row->{'hardduedate'} ne '0000-00-00') {
       my $harddue_dt = eval { dt_from_string( $row->{'hardduedate'} ) };
       $row->{'hardduedate'} = eval { output_pref( { dt => $harddue_dt, dateonly => 1 } ) } if ( $harddue_dt );
       $row->{'hardduedatebefore'} = 1 if ($row->{'hardduedatecompare'} == -1);
       $row->{'hardduedateexact'} = 1 if ($row->{'hardduedatecompare'} ==  0);
       $row->{'hardduedateafter'} = 1 if ($row->{'hardduedatecompare'} ==  1);
    } else {
       $row->{'hardduedate'} = 0;
    }
    if ($row->{no_auto_renewal_after_hard_limit}) {
       my $dt = eval { dt_from_string( $row->{no_auto_renewal_after_hard_limit} ) };
       $row->{no_auto_renewal_after_hard_limit} = eval { output_pref( { dt => $dt, dateonly => 1 } ) } if $dt;
    }

    push @row_loop, $row;
}

my @sorted_row_loop = sort by_category_and_itemtype @row_loop;

$template->param(show_branch_cat_rule_form => 1);

$template->param(
    patron_categories => $patron_categories,
                        itemtypeloop => $itemtypes,
                        rules => \@sorted_row_loop,
                        humanbranch => ($branch ne '*' ? $branch : ''),
                        current_branch => $branch,
                        definedbranch => scalar(@sorted_row_loop)>0
                        );
output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

# sort by patron category, then item type, putting
# default entries at the bottom
sub by_category_and_itemtype {
    unless (by_category($a, $b)) {
        return by_itemtype($a, $b);
    }
}

sub by_category {
    my ($a, $b) = @_;
    if ($a->{'default_humancategorycode'}) {
        return ($b->{'default_humancategorycode'} ? 0 : 1);
    } elsif ($b->{'default_humancategorycode'}) {
        return -1;
    } else {
        return $a->{'humancategorycode'} cmp $b->{'humancategorycode'};
    }
}

sub by_itemtype {
    my ($a, $b) = @_;
    if ($a->{default_translated_description}) {
        return ($b->{'default_translated_description'} ? 0 : 1);
    } elsif ($b->{'default_translated_description'}) {
        return -1;
    } else {
        return lc $a->{'translated_description'} cmp lc $b->{'translated_description'};
    }
}
