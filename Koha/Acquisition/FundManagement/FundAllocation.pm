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
use base qw(Koha::Object Koha::Object::Limit::LibraryGroup);

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

    my $block_fund_value_update = $args->{block_fund_value_update};

    $self->set_lib_group_visibility() if $self->lib_group_visibility;

    if ( $self->allocation_amount < 0 ) {
        $self->will_allocation_breach_spend_limits;
    }

    $self->SUPER::store;

    if ( !$block_fund_value_update ) {
        my $fund = $self->fund;
        $fund->update_fund_value if $fund && !$self->sub_fund_id;
        my $sub_fund = $self->sub_fund;
        $sub_fund->update_sub_fund_value if $sub_fund;
    }

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

=head3 fiscal_period

Method to embed the fiscal period to a given fund allocation

=cut

sub fiscal_period {
    my ($self) = @_;
    my $fiscal_period_rs = $self->_result->fiscal_period;
    return Koha::Acquisition::FundManagement::FiscalPeriod->_new_from_dbic($fiscal_period_rs);
}

=head3 ledger

Method to embed the ledger to a given fund allocation

=cut

sub ledger {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledger;
    return Koha::Acquisition::FundManagement::Ledger->_new_from_dbic($ledger_rs);
}

=head3 fund

Method to embed the fund to a given fund allocation

=cut

sub fund {
    my ($self) = @_;
    my $fund_rs = $self->_result->fund;
    return unless $fund_rs;
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

=head3 owner

Method to embed the owner to a given fund allocation

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 will_allocation_breach_spend_limits

Checks whether the new allocation will breach any spend limits
A I<Koha::Exceptions::Acquisition::FundManagement::LimitExceeded> exception is thrown if it does

=cut

sub will_allocation_breach_spend_limits {
    my ($self) = @_;

    my $ledger = $self->ledger;
    my $result = $ledger->is_ledger_within_spend_limit( { new_allocation => $self->allocation_amount } );
    Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
        data_type => 'ledger',
        amount    => $result->{breach_amount}
    ) if !$result->{within_limit};

    my $fiscal_period = $self->fiscal_period;
    $result = $fiscal_period->is_fiscal_period_within_spend_limit( { new_allocation => $self->allocation_amount } );
    Koha::Exceptions::Acquisition::FundManagement::LimitExceeded->throw(
        data_type => 'fiscal_period',
        amount    => $result->{breach_amount}
    ) if !$result->{within_limit};

    return 0;
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
