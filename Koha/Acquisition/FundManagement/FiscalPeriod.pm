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

use Mojo::JSON qw(decode_json);
use JSON       qw ( encode_json );

use Koha::Acquisition::FundManagement::Utils;


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

    my @ledgers    = $self->ledgers->as_list;
    my $lib_group_visibility = $self->lib_group_visibility;
    my $status     = $self->status;

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
