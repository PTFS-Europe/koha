package Koha::Acquisition::FundManagement::FundAllocation;

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
use base qw(Koha::Object::Limit::LibraryGroup Koha::Acquisition::FundManagement::BaseObject);

use Koha::Acquisition::FundManagement::Fund;
use Koha::Acquisition::FundManagement::SubFunds;
use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::Ledger;
use Koha::Patron;
use Koha::Exceptions::Acquisition::FundManagement;

=head1 NAME

Koha::Acquisition::FundManagement::FundAllocation Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->set_lib_group_visibility() if $self->lib_group_visibility;

    if ( $self->allocation_amount < 0 ) {
        $self->will_allocation_breach_spend_limits;
    }

    $self->SUPER::store;

    return $self;
}

=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 will_allocation_breach_spend_limits

Checks whether the new allocation will breach any spend limits
A I<Koha::Exceptions::Acquisition::FundManagement::LimitExceeded> exception is thrown if it does

=cut

sub will_allocation_breach_spend_limits {
    my ($self) = @_;

    my $result;
    if ( $self->sub_fund_id ) {
        my $sub_fund = $self->sub_fund;
        $result = $sub_fund->is_spend_limit_breached( { new_allocation => $self } );
        Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
            data_type => 'sub_fund',
            amount    => $result->{breach_amount},
        ) if !$result->{within_limit};

        my $fund = $self->sub_fund->fund;
        $result = $fund->is_spend_limit_breached( { new_allocation => $self } );
        Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
            data_type => 'fund',
            amount    => $result->{breach_amount},
        ) if !$result->{within_limit};
    } else {
        my $fund = $self->fund;
        $result = $fund->is_spend_limit_breached( { new_allocation => $self } );
        Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
            data_type => 'fund',
            amount    => $result->{breach_amount},
        ) if !$result->{within_limit};
    }

    my $ledger = $self->ledger;
    $result = $ledger->is_spend_limit_breached( { new_allocation => $self } );
    Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
        data_type => 'ledger',
        amount    => $result->{breach_amount},
    ) if !$result->{within_limit};

    my $fiscal_period = $self->fiscal_period;
    $result = $fiscal_period->is_spend_limit_breached( { new_allocation => $self, over_spend_allowed => 0 } );
    Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
        data_type => 'fiscal_period',
        amount    => $result->{breach_amount},
    ) if !$result->{within_limit};

    return 0;
}


=head3 _object_hierarchy

=cut

sub _object_hierarchy {
    return {
        object   => 'fund_allocation',
    };
}

=head3 _library_group_visibility_parameters

Configure library group limits

=cut

sub _library_group_visibility_parameters {
    return {
        class             => "FundAllocation",
        visibility_column => "lib_group_visibility",
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'FundAllocation';
}

1;
