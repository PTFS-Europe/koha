package Koha::Acquisition::FundManagement::BaseObject;

# Copyright 2024 PTFS Europe

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
use base qw(Koha::Object);

use Scalar::Util qw( looks_like_number );

=head1 NAME

Koha::Acquisition::FundManagement::BaseObject - Koha Object base class for the Fund Management module

=head1 SYNOPSIS

    use Koha::Acquisition::FundManagement::BaseObject;

=head1 DESCRIPTION

This class must always be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 cascade_lib_group_visibility

This method will update the visibility if the parent visibility has changed.
This only works if library groups have been removed i.e. new groups are not automatically cascaded
to prevent data being made visible where it shouldn't be.

=cut

sub cascade_lib_group_visibility {
    my ( $self, $args ) = @_;

    my $parent_visibility = $args->{parent_visibility};
    my $child             = $args->{child};
    my $change_detected;

    if ( $child->lib_group_visibility ne $parent_visibility ) {
        my @child_groups     = split( /\|/, $child->lib_group_visibility );
        my @parent_groups    = split( /\|/, $parent_visibility );
        my @groups_to_keep   = ();
        my @groups_to_delete = ();

        foreach my $group (@child_groups) {
            push( @groups_to_keep,   $group ) if grep( /^$group$/,  @parent_groups ) && $group ne '';
            push( @groups_to_delete, $group ) if !grep( /^$group$/, @parent_groups ) && $group ne '';
        }

        if ( scalar(@groups_to_delete) == 0 ) {
            $change_detected = 0;
        } else {
            $change_detected = 1;
            $child->set_lib_group_visibility( { new_visibility => \@groups_to_keep } );
        }
    }
    return $change_detected;
}

=head3 cascade_status

This method will update the status if the parent status has changed
This only applies to a parent being set to "inactive". Activating a parent object again will not change the status of the child

=cut

sub cascade_status {
    my ( $self, $args ) = @_;

    my $parent_status   = $args->{parent_status};
    my $child           = $args->{child};
    my $change_detected = 0;

    if ( $child->status != $parent_status && $parent_status == 0 ) {
        $child->status($parent_status);
        $change_detected = 1;
    }
    return $change_detected;
}

=head3 cascade_data

=cut

sub cascade_data {
    my ( $self, $args ) = @_;

    my $properties      = $args->{properties};
    my $parent          = $args->{parent};
    my $child           = $args->{child};
    my $change_detected = 0;

    foreach my $property (@$properties) {
        if ( looks_like_number($property) ) {
            if ( $child->$property != $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        } else {
            if ( $child->$property ne $parent->$property ) {
                $child->$property( $parent->$property );
                $change_detected = 1;
            }
        }
    }

    return $change_detected;
}

=head3 fiscal_period

Method to embed the fiscal period to a given fund

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::FundManagement::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}

=head3 ledger

Method to embed the ledger to a given fund

=cut

sub ledger {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledger;
    return Koha::Acquisition::FundManagement::Ledger->_new_from_dbic($ledger_rs);
}

=head3 fund

Method to embed the fund to a given sub fund

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return Koha::Acquisition::FundManagement::Fund->_new_from_dbic($fund_rs);
}

=head3 sub_fund

Method to embed the sub_fund to a given fund allocation

=cut

sub sub_fund {
    my ($self) = @_;
    my $sub_fund_rs = $self->_result->sub_fund;
    return unless $sub_fund_rs;
    return Koha::Acquisition::FundManagement::SubFund->_new_from_dbic($sub_fund_rs);
}

=head3 fund_group

Method to embed the fund group to a given fund

=cut

sub fund_group {
    my ($self) = @_;
    my $fund_group_rs = $self->_result->fund_group;
    return unless $fund_group_rs;
    return Koha::Acquisition::FundManagement::FundGroup->_new_from_dbic($fund_group_rs);
}

=head3 ledgers

Method to embed ledgers to the fiscal period

=cut

sub ledgers {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledgers;
    return Koha::Acquisition::FundManagement::Ledgers->_new_from_dbic($ledger_rs);
}

=head3 funds

Method to embed funds to the fiscal period

=cut

sub funds {
    my ($self) = @_;
    my $fund_rs = $self->_result->funds;
    return Koha::Acquisition::FundManagement::Funds->_new_from_dbic($fund_rs);
}

=head3 sub_funds

Method to embed sub funds to the fund

=cut

sub sub_funds {
    my ($self) = @_;
    my $sub_fund_rs = $self->_result->sub_funds;
    return Koha::Acquisition::FundManagement::SubFunds->_new_from_dbic($sub_fund_rs);
}

=head3 fund_allocations

Method to embed fund allocations to the fund

=cut

sub fund_allocations {
    my ($self) = @_;
    my $fund_allocation_rs = $self->_result->fund_allocations;
    return Koha::Acquisition::FundManagement::FundAllocations->_new_from_dbic($fund_allocation_rs);
}

=head3 owner

Method to embed the owner to a given fund

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 total_allocations

This returns the total actual and committed spend against the object
The total is made up of all the fund allocations against the object

=cut

sub total_allocations {
    my ($self) = @_;

    my $fund_allocations = $self->fund_allocations;
    my $total            = 0;
    foreach my $fund_allocation ( $fund_allocations->as_list ) {
        $total += $fund_allocation->allocation_amount;
    }

    return $total;
}

=head3 total_spent

This returns the total actual spend against the object
The total is made up of all the fund allocations against the object that are not encumbered

=cut

sub total_spent {
    my ($self) = @_;

    my $fund_allocations = $self->fund_allocations->search( { type => { '!=', 'encumbered' } } );
    my $total            = 0;
    foreach my $fund_allocation ( $fund_allocations->as_list ) {
        $total += $fund_allocation->allocation_amount;
    }

    return $total;
}

=head3 total_encumbered

This returns the total non-committed spend against the object
The total is made up of all the fund allocations against the object that are encumbered

=cut

sub total_encumbered {
    my ($self) = @_;

    my $fund_allocations = $self->fund_allocations->search( { type => 'encumbered' } );
    my $total            = 0;
    foreach my $fund_allocation ( $fund_allocations->as_list ) {
        $total += $fund_allocation->allocation_amount;
    }

    return $total;
}

=head3 check_spend_limits

This checks the limits of all child objects under this object to check that they are not in breach of the parent object spend limit
This method is used in the PATCH endpoints in the event that a spend_limit field is updated
The total is made up of the spend_limits for all the child objects attached to the object

=cut

sub check_spend_limits {
    my ( $self, $args ) = @_;

    my $child_class  = $self->_object_hierarchy->{children};
    my @children     = $self->$child_class->as_list;
    my $total        = $args->{new_allocation}  || 0;
    my $spend_limit  = $args->{new_spend_limit} || $self->spend_limit || 0;
    my $id_field     = $self->_object_hierarchy->{child} . "_id";
    my $id_to_ignore = $args->{id_to_ignore} || 0;

    return { within_limit => 1 } if !$spend_limit > 0;

    foreach my $child (@children) {
        my $spend_limit = $child->spend_limit;
        $total += $spend_limit if $child->$id_field != $id_to_ignore;
    }

    my $limit_check   = $spend_limit >= $total        ? 1                     : 0;
    my $breach_amount = ( $total - $spend_limit ) > 0 ? $total - $spend_limit : 0;
    return { within_limit => $limit_check, breach_amount => $breach_amount };
}

=head3 is_spend_limit_breached

Checks whether a new allocation will breach the spend limit of an object
Checks the sum total of all allocations made against the object and the new allocation

It takes into account whether over spend or over encumbrance are allowed on the object

=cut

sub is_spend_limit_breached {
    my ( $self, $args ) = @_;

    my $over_spend_allowed;
    if($self->_type() ne 'FiscalPeriod') {
        $over_spend_allowed = defined $args->{over_spend_allowed} ?  $args->{over_spend_allowed} : $self->over_spend_allowed;
        return { within_limit => 1 } if $over_spend_allowed;
    }

    my $new_allocation        = $args->{new_allocation};
    my $new_allocation_amount = defined $new_allocation ? -$new_allocation->allocation_amount : 0;
    my $new_allocation_type   = defined $new_allocation ? $new_allocation->type               : '';
    my $spend_limit           = $self->spend_limit;
    my $total_allocations     = -$self->total_allocations + $new_allocation_amount;
    my $total_spent =
        $new_allocation_type ne 'encumbered' ? -$self->total_spent + $new_allocation_amount : -$self->total_spent;
    my $total_encumbered =
        $new_allocation_type eq 'encumbered'
        ? -$self->total_encumbered + $new_allocation_amount
        : -$self->total_encumbered;

    my $overspent       = $total_allocations > $spend_limit;

    my $breach_amount = $total_allocations - $spend_limit;
    if ( $self->_type() eq 'FiscalPeriod' ) {
        return { within_limit => 1 } if !$overspent;
        return { within_limit => 0, breach_amount => $breach_amount };
    }

    my $oe_warning_percent = $self->oe_warning_percent || 1;
    my $oe_limit_amount    = $self->oe_limit_amount || $self->spend_limit;
    my $os_warning_sum     = $self->os_warning_sum || $self->spend_limit;
    my $os_limit_sum       = $self->os_limit_sum || $self->spend_limit;

    my $warnings = {
        oe_warning_required => $total_encumbered >= $oe_warning_percent * $spend_limit,
        oe_limit_amount => $total_encumbered >= $oe_limit_amount,
        os_warning_sum => $total_spent >= $os_warning_sum,
        os_limit_sum => $total_spent >= $os_limit_sum,
    };

    return { within_limit => 1, %$warnings } if !$overspent;
    return { within_limit => 0, breach_amount => $breach_amount, %$warnings };
}

=head3 add_accounting_values
    This method takes a hashref as an argument, containing the data to be
    processed.  The data may include funds, sub-funds, and/or fund_allocations.
    The method will calculate the total allocation, allocation_decrease,
    allocation_increase, and net_transfers, and add these values to the
    data hashref.
        
    The method returns the modified data hashref.
=cut

sub add_accounting_values {
    my ( $self, $args ) = @_;

    my $data = $args->{data};

    my @allocations = ();

    if ( defined $data->{funds} ) {
        foreach my $fund ( @{ $data->{funds} } ) {
            if ( defined $fund->{fund_allocations} ) {
                my @fund_allocations = @{ $fund->{fund_allocations} };
                push( @allocations, @fund_allocations );
            }
            if ( defined $fund->{sub_funds} ) {
                foreach my $sub_fund ( @{ $fund->{sub_funds} } ) {
                    if ( defined $sub_fund->{fund_allocations} ) {
                        my @fund_allocations = @{ $sub_fund->{fund_allocations} };
                        push( @allocations, @fund_allocations );
                    }
                }
            }
        }
    }
    if ( defined $data->{fund_allocations} ) {
        push( @allocations, @{ $data->{fund_allocations} } );
    }

    if ( scalar(@allocations) > 0 ) {
        my $allocation_increase = 0;
        my $allocation_decrease = 0;
        my $net_transfers       = 0;

        foreach my $allocation (@allocations) {
            $allocation_increase += $allocation->{allocation_amount} if $allocation->{allocation_amount} > 0;
            $allocation_decrease += $allocation->{allocation_amount} if $allocation->{allocation_amount} < 0;
            $net_transfers       += $allocation->{allocation_amount} if $allocation->{is_transfer};
        }

        my $total_allocation = $allocation_increase + $allocation_decrease;
        $data->{total_allocation}    = $total_allocation;
        $data->{allocation_decrease} = $allocation_decrease;
        $data->{allocation_increase} = $allocation_increase;
        $data->{net_transfers}       = $net_transfers;
    }
    return $data;
}

=head3 to_api

    my $json = $av->to_api;

Overloaded method that returns a JSON representation of the object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $needs_values = delete $self->{add_accounting_values};

    my $response = $self->SUPER::to_api($params);
    $response = $self->add_accounting_values( { data => $response } ) if $needs_values;

    my $object_name = $self->_object_hierarchy()->{object};
    my $value_field = $object_name . "_value";

    $response->{$value_field} = $self->spend_limit + $self->total_allocations
        if $object_name ne 'fund_allocation' && $object_name ne 'fiscal_period';

    my $overrides = {};

    return { %$response, %$overrides };
}

=head3 verify_updated_fields

A method to handle changes to the following fields for ledgers, funds and sub funds:
- spend_limit
- over_spend_allowed

This is a helper method that calls handle_spending_block_changes and handle_spend_limit_changes
It returns an error string if updating the field values will cause a conflict

=cut

sub verify_updated_fields {
    my ( $self, $args ) = @_;

    my $updated_fields = $args->{updated_fields};

    my $error;
    if (   defined $updated_fields->{over_spend_allowed}
        && !$updated_fields->{over_spend_allowed}
        && $updated_fields->{over_spend_allowed} != $self->over_spend_allowed )
    {
        $error = $self->handle_spending_block_changes(
            {
                spend => $updated_fields->{over_spend_allowed},
            }
        );
        return $error if $error;
    }

    my $over_spend_allowed =
        defined $updated_fields->{over_spend_allowed}
        ? $updated_fields->{over_spend_allowed}
        : $self->over_spend_allowed;
    if ( defined $updated_fields->{spend_limit} && $updated_fields->{spend_limit} != $self->spend_limit ) {
        $error = $self->handle_spend_limit_changes(
            { new_limit => $updated_fields->{spend_limit}, over_spend_allowed => $over_spend_allowed } );
        return $error if $error;
    }

    return;
}

=head3 handle_spending_block_changes

A method to handle changes to the following fields for ledgers, funds and sub funds:
- over_spend_allowed

The method is only called if either over spend or over encumbrance is changed to be blocked, i.e. set to 0
It checks whether the object is overspent or overspent and encumbered and returns an error message if so

=cut

sub handle_spending_block_changes {
    my ( $self, $args ) = @_;

    my $object_hierarchy = $self->_object_hierarchy();

    my $result = $self->is_spend_limit_breached( { new_allocation => undef, over_spend_allowed => $args->{spend} } );

    return
          "You cannot prevent overspend on a "
        . _format_object_name( $object_hierarchy->{object} )
        . " that is already overspent"
        if !$result->{within_limit};

    return;
}

=head3 handle_spend_limit_changes

A method to handle changes to the following fields for ledgers, funds and sub funds:
- spend_limit

If the spend limit is increased, it checks that the sum of all allocations is not greater than the new spend limit
It also checks that the sum of the spend_limits of all child objects would not exceed the new limit

If the spend limit is decreased, it checks that the sum

=cut

sub handle_spend_limit_changes {
    my ( $self, $args ) = @_;

    my $new_limit          = $args->{new_limit};
    my $over_spend_allowed = $args->{over_spend_allowed} || $self->over_spend_allowed;
    my $object_hierarchy   = $self->_object_hierarchy();

    if ( $new_limit < -$self->total_allocations && !$over_spend_allowed ) {
        return
              "Spend limit cannot be less than the "
            . $object_hierarchy->{object}
            . " spend when overspend is not allowed";
    }

    my $parent_object = $object_hierarchy->{parent};
    my $parent        = $self->$parent_object;
    my $id_field      = $object_hierarchy->{object} . "_id";

    my $spend_limit_diff = $new_limit - $self->spend_limit;
    my $result =
        $parent->check_spend_limits( { new_allocation => $spend_limit_diff, id_to_ignore => $self->$id_field } );

    return
          "Spend limit breached for the "
        . _format_object_name( $object_hierarchy->{parent_object} )
        . ", please reduce spend limit on the "
        . _format_object_name( $object_hierarchy->{object} ) . " by "
        . $result->{breach_amount}
        . " or increase the spend limit for the "
        . _format_object_name( $object_hierarchy->{parent_object} )
        unless $result->{within_limit};

    $result = $self->check_spend_limits( { new_spend_limit => $new_limit } );

    return
          "The "
        . _format_object_name( $object_hierarchy->{object} )
        . " spend limit is less than the total of the spend limits for the "
        . _format_object_name( $object_hierarchy->{children} )
        . " below, please increase spend limit by "
        . $result->{breach_amount}
        . " or decrease the spend limit for the "
        . _format_object_name( $object_hierarchy->{children} )
        unless $result->{within_limit};

    return;
}

sub _format_object_name {
    my ($name) = @_;

    $name =~ s/_/ /g;
    return $name;
}
1;
