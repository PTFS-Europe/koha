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

use Mojo::JSON qw(decode_json);
use JSON       qw ( encode_json );


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

=head3 update_ledger_total

This method is triggered whenever a fund value is updated and updates the value of the relevant ledger.
It only takes into account positive allocations - the funds underneath the ledger deal with and spend/orders

=cut

sub update_ledger_total {
    my ( $self, $args ) = @_;

    my $allocations = $self->fund_allocations;
    my $total       = 0;
    foreach my $allocation ( $allocations->as_list ) {
        $total += $allocation->allocation_amount if $allocation->allocation_amount > 0;
    }

    $self->ledger_value($total)->store({ no_cascade => 1 });
    return $total;
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
