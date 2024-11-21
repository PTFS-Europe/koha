package Koha::REST::V1::Acquisitions::FundManagement::Util;

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

=head1 API

=head2 Methods

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
            my @fund_allocations = @{ $fund->{fund_allocations} };
            push( @allocations, @fund_allocations );
        }
    }
    if ( defined $data->{sub_funds} ) {
        foreach my $sub_fund ( @{ $data->{sub_funds} } ) {
            if ( defined $sub_fund->{fund_allocations} ) {
                my @fund_allocations = @{ $sub_fund->{fund_allocations} };
                push( @allocations, @fund_allocations );
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

1;
