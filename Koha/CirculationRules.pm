package Koha::CirculationRules;

# Copyright ByWater Solutions 2017
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
use Carp qw( croak );

use Koha::Exceptions;
use Koha::CirculationRule;

use base qw(Koha::Objects);

use constant GUESSED_ITEMTYPES_KEY => 'Koha_IssuingRules_last_guess';

=head1 NAME

Koha::CirculationRules - Koha CirculationRule Object set class

=head1 API

=head2 Class Methods

=cut

=head3 rule_kinds

This structure describes the possible rules that may be set, and what scopes they can be set at.

Any attempt to set a rule with a nonsensical scope (for instance, setting the C<patron_maxissueqty> for a branchcode and itemtype), is an error.

=cut

our $RULE_KINDS = {
    lostreturn => {
        scope => [ 'branchcode' ],
    },

    patron_maxissueqty => {
        scope => [ 'branchcode', 'categorycode' ],
    },
    patron_maxonsiteissueqty => {
        scope => [ 'branchcode', 'categorycode' ],
    },
    max_holds => {
        scope => [ 'branchcode', 'categorycode' ],
    },

    bookingsallowed => {
        scope => [ 'branchcode', 'itemtype' ],
        can_be_blank => 0,
    },
    holdallowed => {
        scope => [ 'branchcode', 'itemtype' ],
        can_be_blank => 0,
    },
    hold_fulfillment_policy => {
        scope => [ 'branchcode', 'itemtype' ],
        can_be_blank => 0,
    },
    returnbranch => {
        scope => [ 'branchcode', 'itemtype' ],
        can_be_blank => 0,
    },

    article_requests => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    open_article_requests_limit => {
        scope => [ 'branchcode', 'categorycode' ],
    },

    auto_renew => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    cap_fine_to_replacement_price => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    chargeperiod => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    chargeperiod_charge_at => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    fine => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    finedays => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    firstremind => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    hardduedate => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    hardduedatecompare => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    holds_per_day => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    holds_per_record => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    issuelength => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    daysmode => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    lengthunit => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxissueqty => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxonsiteissueqty => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    maxsuspensiondays => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    no_auto_renewal_after => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    no_auto_renewal_after_hard_limit => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    norenewalbefore => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    onshelfholds => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    opacitemholds => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    overduefinescap => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    renewalperiod => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    renewalsallowed => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    unseen_renewals_allowed => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    rentaldiscount => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
        can_be_blank => 0,
    },
    reservesallowed => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    suspension_chargeperiod => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    note => { # This is not really a rule. Maybe we will want to separate this later.
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    decreaseloanholds => {
        scope => [ 'branchcode', 'categorycode', 'itemtype' ],
    },
    # Not included (deprecated?):
    #   * accountsent
    #   * reservecharge
    #   * restrictedtype
};

sub rule_kinds {
    return $RULE_KINDS;
}

=head3 get_effective_rule

=cut

sub get_effective_rule {
    my ( $self, $params ) = @_;

    $params->{categorycode} //= undef;
    $params->{branchcode}   //= undef;
    $params->{itemtype}     //= undef;

    my $rule_name    = $params->{rule_name};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $branchcode   = $params->{branchcode};

    Koha::Exceptions::MissingParameter->throw(
        "Required parameter 'rule_name' missing")
      unless $rule_name;

    for my $v ( $branchcode, $categorycode, $itemtype ) {
        $v = undef if $v and $v eq '*';
    }

    my $order_by = $params->{order_by}
      // { -desc => [ 'branchcode', 'categorycode', 'itemtype' ] };

    my $search_params;
    $search_params->{rule_name} = $rule_name;

    $search_params->{categorycode} = defined $categorycode ? [ $categorycode, undef ] : undef;
    $search_params->{itemtype}     = defined $itemtype     ? [ $itemtype, undef ] : undef;
    $search_params->{branchcode}   = defined $branchcode   ? [ $branchcode,   undef ] : undef;

    my $rule = $self->search(
        $search_params,
        {
            order_by => $order_by,
            rows => 1,
        }
    )->single;

    return $rule;
}

=head3 get_effective_rules

=cut

sub get_effective_rules {
    my ( $self, $params ) = @_;

    my $rules        = $params->{rules};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $branchcode   = $params->{branchcode};

    my $r;
    foreach my $rule (@$rules) {
        my $effective_rule = $self->get_effective_rule(
            {
                rule_name    => $rule,
                categorycode => $categorycode,
                itemtype     => $itemtype,
                branchcode   => $branchcode,
            }
        );

        $r->{$rule} = $effective_rule->rule_value if $effective_rule;
    }

    return $r;
}

=head3 set_rule

=cut

sub set_rule {
    my ( $self, $params ) = @_;

    for my $mandatory_parameter (qw( rule_name rule_value ) ) {
        Koha::Exceptions::MissingParameter->throw(
            "Required parameter '$mandatory_parameter' missing")
          unless exists $params->{$mandatory_parameter};
    }

    my $kind_info = $RULE_KINDS->{ $params->{rule_name} };
    Koha::Exceptions::MissingParameter->throw(
        "set_rule given unknown rule '$params->{rule_name}'!")
        unless defined $kind_info;

    # Enforce scope; a rule should be set for its defined scope, no more, no less.
    foreach my $scope_level ( qw( branchcode categorycode itemtype ) ) {
        if ( grep /$scope_level/, @{ $kind_info->{scope} } ) {
            croak "set_rule needs '$scope_level' to set '$params->{rule_name}'!"
                unless exists $params->{$scope_level};
        } else {
            croak "set_rule cannot set '$params->{rule_name}' for a '$scope_level'!"
                if exists $params->{$scope_level};
        }
    }

    my $branchcode   = $params->{branchcode};
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $rule_name    = $params->{rule_name};
    my $rule_value   = $params->{rule_value};
    my $can_be_blank = defined $kind_info->{can_be_blank} ? $kind_info->{can_be_blank} : 1;
    $rule_value = undef if defined $rule_value && $rule_value eq "" && !$can_be_blank;

    for my $v ( $branchcode, $categorycode, $itemtype ) {
        $v = undef if $v and $v eq '*';
    }
    my $rule = $self->search(
        {
            rule_name    => $rule_name,
            branchcode   => $branchcode,
            categorycode => $categorycode,
            itemtype     => $itemtype,
        }
    )->next();

    if ($rule) {
        if ( defined $rule_value ) {
            $rule->rule_value($rule_value);
            $rule->update();
        }
        else {
            $rule->delete();
        }
    }
    else {
        if ( defined $rule_value ) {
            $rule = Koha::CirculationRule->new(
                {
                    branchcode   => $branchcode,
                    categorycode => $categorycode,
                    itemtype     => $itemtype,
                    rule_name    => $rule_name,
                    rule_value   => $rule_value,
                }
            );
            $rule->store();
        }
    }

    return $rule;
}

=head3 set_rules

=cut

sub set_rules {
    my ( $self, $params ) = @_;

    my %set_params;
    $set_params{branchcode} = $params->{branchcode} if exists $params->{branchcode};
    $set_params{categorycode} = $params->{categorycode} if exists $params->{categorycode};
    $set_params{itemtype} = $params->{itemtype} if exists $params->{itemtype};
    my $rules        = $params->{rules};

    my $rule_objects = [];
    while ( my ( $rule_name, $rule_value ) = each %$rules ) {
        my $rule_object = Koha::CirculationRules->set_rule(
            {
                %set_params,
                rule_name    => $rule_name,
                rule_value   => $rule_value,
            }
        );
        push( @$rule_objects, $rule_object );
    }

    return $rule_objects;
}

=head3 delete

Delete a set of circulation rules, needed for cleaning up when deleting issuingrules

=cut

sub delete {
    my ( $self ) = @_;

    while ( my $rule = $self->next ){
        $rule->delete;
    }
}

=head3 clone

Clone a set of circulation rules to another branch

=cut

sub clone {
    my ( $self, $to_branch ) = @_;

    while ( my $rule = $self->next ){
        $rule->clone($to_branch);
    }
}

=head3 get_opacitemholds_policy

my $can_place_a_hold_at_item_level = Koha::CirculationRules->get_opacitemholds_policy( { patron => $patron, item => $item } );

Return 'Y' or 'F' if the patron can place a hold on this item according to the issuing rules
and the "Item level holds" (opacitemholds).
Can be 'N' - Don't allow, 'Y' - Allow, and 'F' - Force

=cut

sub get_opacitemholds_policy {
    my ( $class, $params ) = @_;

    my $item   = $params->{item};
    my $patron = $params->{patron};

    return unless $item or $patron;

    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            categorycode => $patron->categorycode,
            itemtype     => $item->effective_itemtype,
            branchcode   => $item->homebranch,
            rule_name    => 'opacitemholds',
        }
    );

    return $rule ? $rule->rule_value : undef;
}

=head3 get_onshelfholds_policy

    my $on_shelf_holds = Koha::CirculationRules->get_onshelfholds_policy({ item => $item, patron => $patron });

=cut

sub get_onshelfholds_policy {
    my ( $class, $params ) = @_;
    my $item = $params->{item};
    my $itemtype = $item->effective_itemtype;
    my $patron = $params->{patron};
    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            categorycode => ( $patron ? $patron->categorycode : undef ),
            itemtype     => $itemtype,
            branchcode   => $item->holdingbranch,
            rule_name    => 'onshelfholds',
        }
    );
    return $rule ? $rule->rule_value : 0;
}

=head3 get_lostreturn_policy

  my $lostrefund_policy = Koha::CirculationRules->get_lostreturn_policy( { return_branch => $return_branch, item => $item } );

Return values are:

=over 2

=item '0' - Do not refund

=item 'refund' - Refund the lost item charge

=item 'restore' - Refund the lost item charge and restore the original overdue fine

=item 'charge' - Refund the lost item charge and charge a new overdue fine

=back

=cut

sub get_lostreturn_policy {
    my ( $class, $params ) = @_;

    my $item   = $params->{item};

    my $behaviour = C4::Context->preference( 'RefundLostOnReturnControl' ) // 'CheckinLibrary';
    my $behaviour_mapping = {
        CheckinLibrary    => $params->{'return_branch'} // $item->homebranch,
        ItemHomeBranch    => $item->homebranch,
        ItemHoldingBranch => $item->holdingbranch
    };

    my $branch = $behaviour_mapping->{ $behaviour };

    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            branchcode => $branch,
            rule_name  => 'lostreturn',
        }
    );

    return $rule ? $rule->rule_value : 'refund';
}

=head3 article_requestable_rules

    Return rules that allow article requests, optionally filtered by
    patron categorycode.

    Use with care; see guess_article_requestable_itemtypes.

=cut

sub article_requestable_rules {
    my ( $class, $params ) = @_;
    my $category = $params->{categorycode};

    return if !C4::Context->preference('ArticleRequests');
    return $class->search({
        $category ? ( categorycode => [ $category, undef ] ) : (),
        rule_name => 'article_requests',
        rule_value => { '!=' => 'no' },
    });
}

=head3 guess_article_requestable_itemtypes

    Return item types in a hashref that are likely possible to be
    'article requested'. Constructed by an intelligent guess in the
    issuing rules (see article_requestable_rules).

    Note: pref ArticleRequestsLinkControl overrides the algorithm.

    Optional parameters: categorycode.

    Note: the routine is used in opac-search to obtain a reasonable
    estimate within performance borders (not looking at all items but
    just using default itemtype). Also we are not looking at the
    branchcode here, since home or holding branch of the item is
    leading and branch may be unknown too (anonymous opac session).

=cut

sub guess_article_requestable_itemtypes {
    my ( $class, $params ) = @_;
    my $category = $params->{categorycode};
    return {} if !C4::Context->preference('ArticleRequests');
    return { '*' => 1 } if C4::Context->preference('ArticleRequestsLinkControl') eq 'always';

    my $cache = Koha::Caches->get_instance;
    my $last_article_requestable_guesses = $cache->get_from_cache(GUESSED_ITEMTYPES_KEY);
    my $key = $category || '*';
    return $last_article_requestable_guesses->{$key}
        if $last_article_requestable_guesses && exists $last_article_requestable_guesses->{$key};

    my $res = {};
    my $rules = $class->article_requestable_rules({
        $category ? ( categorycode => $category ) : (),
    });
    return $res if !$rules;
    foreach my $rule ( $rules->as_list ) {
        $res->{ $rule->itemtype // '*' } = 1;
    }
    $last_article_requestable_guesses->{$key} = $res;
    $cache->set_in_cache(GUESSED_ITEMTYPES_KEY, $last_article_requestable_guesses);
    return $res;
}

=head3 get_daysmode_effective_value

Return the value for daysmode defined in the circulation rules.
If not defined (or empty string), the value of the system preference useDaysMode is returned

=cut

sub get_effective_daysmode {
    my ( $class, $params ) = @_;

    my $categorycode     = $params->{categorycode};
    my $itemtype         = $params->{itemtype};
    my $branchcode       = $params->{branchcode};

    my $daysmode_rule = $class->get_effective_rule(
        {
            categorycode => $categorycode,
            itemtype     => $itemtype,
            branchcode   => $branchcode,
            rule_name    => 'daysmode',
        }
    );

    return ( defined($daysmode_rule)
          and $daysmode_rule->rule_value ne '' )
      ? $daysmode_rule->rule_value
      : C4::Context->preference('useDaysMode');

}


=head3 type

=cut

sub _type {
    return 'CirculationRule';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::CirculationRule';
}

1;
