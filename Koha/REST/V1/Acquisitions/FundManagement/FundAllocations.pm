package Koha::REST::V1::Acquisitions::FundManagement::FundAllocations;

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

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json);
use Try::Tiny;

use Koha::Acquisition::FundManagement::Funds;
use Koha::Acquisition::FundManagement::FundAllocation;
use Koha::Acquisition::FundManagement::FundAllocations;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $fund_allocations_set = Koha::Acquisition::FundManagement::FundAllocations->new;
        my $fund_allocations     = $c->objects->search($fund_allocations_set);

        my $sorted_allocations = Koha::Acquisition::FundManagement::FundAllocations->add_totals_to_fund_allocations(
            { allocations => $fund_allocations } );

        return $c->render( status => 200, openapi => $sorted_allocations );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $fund_allocations_set = Koha::Acquisition::FundManagement::FundAllocations->new;
        my $fund_allocation      = $c->objects->find( $fund_allocations_set, $c->param('fund_allocation_id') );

        unless ($fund_allocation) {
            return $c->render(
                status  => 404,
                openapi => { error => "Fund allocation not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $fund_allocation
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;
                delete $body->{lib_groups} if $body->{lib_groups};

                my $fund_allocation = Koha::Acquisition::FundManagement::FundAllocation->new_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fund_allocation->fund_allocation_id );
                return $c->render(
                    status  => 201,
                    openapi => $fund_allocation->to_api
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::FundManagement::FundAllocation object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $fund_allocation = Koha::Acquisition::FundManagement::FundAllocations->find( $c->param('fund_allocation_id') );

    unless ($fund_allocation) {
        return $c->render(
            status  => 404,
            openapi => { error => "Fund allocation not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                delete $body->{lib_groups}    if $body->{lib_groups};
                delete $body->{fiscal_period} if $body->{fiscal_period};
                delete $body->{last_updated}  if $body->{last_updated};

                $fund_allocation->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fund_allocation->fund_allocation_id );
                return $c->render(
                    status  => 200,
                    openapi => $fund_allocation->to_api
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::FundAllocation->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->broken_fk } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Given " . $to_api_mapping->{ $_->parameter } . " does not exist" }
                );
            } elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $fund_allocation = Koha::Acquisition::FundManagement::FundAllocations->find( $c->param('fund_allocation_id') );
    unless ($fund_allocation) {
        return $c->render(
            status  => 404,
            openapi => { error => "Fund allocation not found" }
        );
    }

    return try {
        my $fund_id = $fund_allocation->fund_id;
        $fund_allocation->delete;

        return $c->render(
            status  => 204,
            openapi => q{}
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 transfer

=cut

sub transfer {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {
                # Currency needs reviewing - fx calculation may be required
                my $body = $c->req->json;

                my $fund_transferring_from =
                    Koha::Acquisition::FundManagement::Funds->find( { fund_id => $body->{fund_id_from} } );
                my $fund_transferring_to =
                    Koha::Acquisition::FundManagement::Funds->find( { fund_id => $body->{fund_id_to} } );
                my $sub_fund_transferring_from =
                    Koha::Acquisition::FundManagement::SubFunds->find( { sub_fund_id => $body->{sub_fund_id_from} } );
                my $sub_fund_transferring_to =
                    Koha::Acquisition::FundManagement::SubFunds->find( { sub_fund_id => $body->{sub_fund_id_to} } );

                my $note_from = "Transfer to "
                    . ( $sub_fund_transferring_to ? $sub_fund_transferring_to->name : $fund_transferring_to->name );
                $note_from = $note_from . ": " . $body->{note} if $body->{note};
                my $note_to =
                    "Transfer from "
                    . (
                    $sub_fund_transferring_from ? $sub_fund_transferring_from->name : $fund_transferring_from->name );
                $note_to = $note_to . ": " . $body->{note} if $body->{note};

                my $fund_id_from = $body->{sub_fund_id_from} ? undef : $body->{fund_id_from};
                my $fund_id_to   = $body->{sub_fund_id_to}   ? undef : $body->{fund_id_to};

                my $allocation_from = Koha::Acquisition::FundManagement::FundAllocation->new(
                    {
                        fund_id           => $fund_id_from,
                        sub_fund_id       => $body->{sub_fund_id_from},
                        ledger_id         => $fund_transferring_from->ledger_id,
                        fiscal_period_id  => $fund_transferring_from->fiscal_period_id,
                        allocation_amount => -$body->{transfer_amount},
                        reference         => $body->{reference},
                        note              => $note_from,
                        currency          => $fund_transferring_from->currency,
                        owner             => $fund_transferring_from->owner,
                        lib_group_visibility        => $fund_transferring_from->lib_group_visibility,
                        is_transfer       => 1
                    }
                )->store();
                my $allocation_to = Koha::Acquisition::FundManagement::FundAllocation->new(
                    {
                        fund_id           => $fund_id_to,
                        sub_fund_id       => $body->{sub_fund_id_to},
                        ledger_id         => $fund_transferring_to->ledger_id,
                        fiscal_period_id  => $fund_transferring_to->fiscal_period_id,
                        allocation_amount => $body->{transfer_amount},
                        reference         => $body->{reference},
                        note              => $note_to,
                        currency          => $fund_transferring_to->currency,
                        owner             => $fund_transferring_to->owner,
                        lib_group_visibility        => $fund_transferring_to->lib_group_visibility,
                        is_transfer       => 1
                    }
                )->store();

                return $c->render(
                    status  => 201,
                    openapi => { msg => 'Success' }
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };

}

1;
