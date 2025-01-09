package Koha::Acquisition::FundManagement::SubFund;

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
use base qw(Koha::Object Koha::Object::Limit::LibraryGroup);

use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::Ledger;
use Koha::Acquisition::FundManagement::Fund;
use Koha::Acquisition::FundManagement::FundAllocations;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::SubFund Object class

=head1 API

=head2 Class methods

=head3 store

=cut 

sub store {
    my ( $self, $args ) = @_;

    if ( !$self->sub_fund_value && !$self->fund_allocations->count ) {
        $self->sub_fund_value( $self->spend_limit );
    }

    $self->set_lib_group_visibility() if $self->lib_group_visibility;
    $self->SUPER::store;

    $self->cascade_to_fund_allocations unless $args->{no_cascade};

    return $self;
}

=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    my $fund = $self->fund;
    $fund->update_fund_value;

    return $self;
}

=head3 cascade_to_fund_allocations

This method cascades changes to the values of the "lib_group_visibility" and "status" properties to all fund_allocations attached to this ledger

=cut

sub cascade_to_fund_allocations {
    my ( $self, $args ) = @_;

    my @fund_allocations     = $self->fund_allocations->as_list;
    my $lib_group_visibility = $self->lib_group_visibility;
    my $status               = $self->status;

    foreach my $fund_allocation (@fund_allocations) {
        my $visibility_updated = Koha::Acquisition::FundManagement::Utils->cascade_lib_group_visibility(
            {
                parent_visibility => $lib_group_visibility,
                child             => $fund_allocation
            }
        );
        my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id', 'ledger_id' );
        my $data_updated    = Koha::Acquisition::FundManagement::Utils->cascade_data(
            {
                parent     => $self,
                child      => $fund_allocation,
                properties => \@data_to_cascade
            }
        );
        $fund_allocation->store( { block_fund_value_update => 1 } ) if $visibility_updated || $data_updated;
    }
}

=head3 update_fund_value

This method is called whenever a fund allocation is made.
It updates the value of the fund based on the fund allocations and then triggers an update to the ledger value

=cut

sub update_sub_fund_value {
    my ( $self, $args ) = @_;

    my @allocations = $self->fund_allocations->as_list;
    my $total       = 0;

    foreach my $allocation (@allocations) {
        $total += $allocation->allocation_amount;
    }
    $self->sub_fund_value($total)->store( { no_cascade => 1 } );

    my $fund = $self->fund;
    $fund->update_fund_value;

    return $total;
}

=head3 is_sub_fund_within_spend_limit

Checks whether a sub_fund is within the spend limit
For a sub_fund, the spend limit is the sub_fund_value as this is the limit on the sub_fund minus any spend
Returns the result, including the amount of any breach and whether overspend/overencumbrance are allowed on the sub_fund

=cut

sub is_sub_fund_within_spend_limit {
    my ( $self, $args ) = @_;

    my $new_allocation = $args->{new_allocation};
    my $spend_limit    = $self->sub_fund_value;
    my $total_spent    = $self->sub_fund_spent + $new_allocation;

    return {
        within_limit       => -$total_spent <= $spend_limit, breach_amount            => $total_spent + $spend_limit,
        over_spend_allowed => $self->over_spend_allowed,     over_encumbrance_allowed => $self->over_encumbrance_allowed
    };
}

=head3 sub_fund_spent

This returns the total actual and committed spend against the sub_fund
The total is made up of all the sub_fund allocations against the sub_fund

=cut

sub sub_fund_spent {
    my ($self) = @_;

    my $fund_allocations = $self->fund_allocations;
    my $total            = 0;
    foreach my $fund_allocation ( $fund_allocations->as_list ) {
        $total += $fund_allocation->allocation_amount;
    }

    return $total;
}

=head3 fiscal_period

Method to embed the fiscal period to a given sub fund

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::FundManagement::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}

=head3 ledger

Method to embed the ledger to a given sub fund

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

=head3 fund_allocations

Method to embed fund allocations to the fund

=cut

sub fund_allocations {
    my ($self) = @_;
    my $fund_allocation_rs = $self->_result->fund_allocations;
    return Koha::Acquisition::FundManagement::FundAllocations->_new_from_dbic($fund_allocation_rs);
}

=head3 owner

Method to embed the owner to a given sub fund

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 _library_group_visibility_parameters

Configure library group limits

=cut

sub _library_group_visibility_parameters {
    return {
        class             => "SubFund",
        visibility_column => "lib_group_visibility",
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'SubFund';
}

1;
