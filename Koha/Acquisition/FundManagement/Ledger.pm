package Koha::Acquisition::FundManagement::Ledger;

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

use Koha::Acquisition::FundManagement::Funds;
use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::FundAllocations;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::Ledger Object class

=head1 API

=head2 Class methods

=head3 store

=cut 

sub store {
    my ( $self, $args ) = @_;

    $self->set_lib_group_visibility() if $self->lib_group_visibility;
    $self->SUPER::store;

    $self->cascade_to_funds unless $args->{no_cascade};

    return $self;
}


=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}


=head3 cascade_to_funds

This method cascades changes to the values of the "lib_group_visibility" and "status" properties to all funds attached to this ledger

=cut

sub cascade_to_funds {
    my ( $self, $args ) = @_;

    my @funds      = $self->funds->as_list;
    my $lib_group_visibility = $self->lib_group_visibility;
    my $status     = $self->status;

    foreach my $fund (@funds) {
        my $status_updated = Koha::Acquisition::FundManagement::Utils->cascade_status(
            {
                parent_status => $status,
                child         => $fund
            }
        );
        my $visibility_updated = Koha::Acquisition::FundManagement::Utils->cascade_lib_group_visibility(
            {
                parent_visibility => $lib_group_visibility,
                child             => $fund
            }
        );
        my @data_to_cascade = ( 'fiscal_period_id', 'currency', 'owner_id' );
        my $data_updated = Koha::Acquisition::FundManagement::Utils->cascade_data({
            parent => $self,
            child => $fund,
            properties => \@data_to_cascade
        });
        $fund->store() if $status_updated || $visibility_updated || $data_updated;
    }
}

=head3 update_ledger_value

This method is triggered whenever a fund value is updated and updates the value of the relevant ledger.
It only takes into account positive allocations - the funds underneath the ledger deal with and spend/orders

=cut

sub update_ledger_value {
    my ( $self, $args ) = @_;

    my $allocations  = $self->fund_allocations;
    my $ledger_total = 0;

    if ( $self->spend_limit > 0 ) {
        my $allocation_total = 0;
        foreach my $allocation ( $allocations->as_list ) {
            $allocation_total += $allocation->allocation_amount if $allocation->allocation_amount < 0;
        }
        $ledger_total = $self->spend_limit + $allocation_total;
    } else {
        foreach my $allocation ( $allocations->as_list ) {
            $ledger_total += $allocation->allocation_amount if $allocation->allocation_amount > 0;
        }
    }

    $self->ledger_value($ledger_total)->store( { no_cascade => 1 } );
    return $ledger_total;
}

=head3 fiscal_period

Method to embed the fiscal period to a given ledger

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::FundManagement::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}


=head3 funds

Method to embed funds to the fiscal period

=cut

sub funds {
    my ($self) = @_;
    my $fund_rs = $self->_result->funds;
    return Koha::Acquisition::FundManagement::Funds->_new_from_dbic($fund_rs);
}

=head3 fund_allocations

Method to embed fund_allocations to the fiscal period

=cut

sub fund_allocations {
    my ($self) = @_;
    my $fund_allocation_rs = $self->_result->fund_allocations;
    return Koha::Acquisition::FundManagement::FundAllocations->_new_from_dbic($fund_allocation_rs);
}


=head3 owner

Method to embed the owner to a given ledger

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 is_ledger_within_spend_limit

Checks whether a ledger is within the spend limit
For a ledger, the spend limit is the ledger_value as this field is made up as follows
- If an explicit spend_limit has been set on the ledger then it is the spend limit minus any spend against the ledger, giving the remaining value
- If no spend_limit has been set on the ledger then the spend limit is the ledger_value as this is the sum of positive fund allocations
Returns the result, including the amount of any breach and whether overspend/overencumbrance are allowed on the ledger

=cut

sub is_ledger_within_spend_limit {
    my ( $self, $args ) = @_;

    my $new_allocation = $args->{new_allocation};
    my $spend_limit    = $self->ledger_value;
    my $total_spent    = $self->ledger_spent + $new_allocation;

    return {
        within_limit       => -$total_spent <= $spend_limit, breach_amount            => $total_spent + $spend_limit,
        over_spend_allowed => $self->over_spend_allowed,    over_encumbrance_allowed => $self->over_encumbrance_allowed
    };
}

=head3 ledger_spent

This returns the total actual and committed spend against the ledger
The total is made up of all the fund allocations against the ledger

=cut

sub ledger_spent {
    my ($self) = @_;

    my $fund_allocations = $self->fund_allocations;
    my $total            = 0;
    foreach my $fund_allocation ( $fund_allocations->as_list ) {
        $total += $fund_allocation->allocation_amount if $fund_allocation->allocation_amount < 0;
    }

    return $total;
}

=head3 _library_group_visibility_parameters

Configure library group limits

=cut

sub _library_group_visibility_parameters {
    return {
        class             => "Ledger",
        visibility_column => "lib_group_visibility",
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Ledger';
}

1;
