package Koha::Acquisition::FundManagement::FiscalPeriod;

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

use Koha::Acquisition::FundManagement::Utils;
use Koha::Acquisition::FundManagement::Ledgers;
use Koha::Patron;

=head1 NAME

Koha::Acquisition::FundManagement::FiscalPeriod Object class

=head1 API

=head2 Class methods

=head3 store

=cut

sub store {
    my ( $self, $args ) = @_;

    $self->set_lib_group_visibility() if $self->lib_group_visibility;
    $self->SUPER::store;

    $self->cascade_to_ledgers unless $args->{no_cascade};

    return $self;
}

=head3 delete

=cut

sub delete {
    my ( $self, $args ) = @_;

    my $deleted = $self->_result()->delete;

    return $self;
}

=head3 cascade_to_ledgers

This method cascades changes to the values of the "lib_group_visibility" and "status" properties to all ledgers attached to this fiscal period

=cut

sub cascade_to_ledgers {
    my ( $self, $args ) = @_;

    my @ledgers              = $self->ledgers->as_list;
    my $lib_group_visibility = $self->lib_group_visibility;
    my $status               = $self->status;

    foreach my $ledger (@ledgers) {
        my $status_updated = Koha::Acquisition::FundManagement::Utils->cascade_status(
            {
                parent_status => $status,
                child         => $ledger
            }
        );
        my $visibility_updated = Koha::Acquisition::FundManagement::Utils->cascade_lib_group_visibility(
            {
                parent_visibility => $lib_group_visibility,
                child             => $ledger
            }
        );
        $ledger->store() if $status_updated || $visibility_updated;
    }
}

=head3 ledgers

Method to embed ledgers to the fiscal period

=cut

sub ledgers {
    my ($self) = @_;
    my $ledger_rs = $self->_result->ledgers;
    return Koha::Acquisition::FundManagement::Ledgers->_new_from_dbic($ledger_rs);
}

=head3 owner

Method to embed the owner to a given fiscal period

=cut

sub owner {
    my ($self) = @_;
    my $owner_rs = $self->_result->owner;
    return Koha::Patron->_new_from_dbic($owner_rs);
}

=head3 is_fiscal_period_within_spend_limit

Checks whether a fiscal period is within the spend limit

=cut

sub is_fiscal_period_within_spend_limit {
    my ( $self, $args ) = @_;

    return { within_limit => 1 } unless $self->spend_limit > 0;

    my $new_allocation = $args->{new_allocation};
    my $spend_limit    = $self->spend_limit;
    my $total_spent    = $self->fiscal_period_spent + $new_allocation;

    return { within_limit => -$total_spent <= $spend_limit, breach_amount => $total_spent + $spend_limit };
}

=head3 fiscal_period_spent

This returns the total actual and committed spend against the fiscal period

=cut

sub fiscal_period_spent {
    my ($self) = @_;

    my @ledgers = $self->ledgers->as_list;
    my $total   = 0;

    foreach my $ledger (@ledgers) {
        $total += $ledger->ledger_spent;
    }

    return $total;
}

=head3 fiscal_period_ledger_limits

This returns the spending limits of the ledgers under a fiscal period
The total is made up of the spend_limits for all the ledgers attached to the fiscal period

=cut

sub fiscal_period_ledger_limits {
    my ($self) = @_;

    my @ledgers = $self->ledgers->as_list;
    my $total   = 0;

    return { within_limit => 1 } if !$self->spend_limit > 0;

    foreach my $ledger (@ledgers) {
        my $spend_limit = $ledger->spend_limit;
        $total += $spend_limit;
    }

    return { within_limit => $self->spend_limit >= $total, breach_amount => $total - $self->spend_limit };
}

=head3 _library_group_visibility_parameters

Configure library group limits

=cut

sub _library_group_visibility_parameters {
    return {
        class             => "FiscalPeriod",
        visibility_column => "lib_group_visibility",
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'FiscalPeriod';
}

1;
