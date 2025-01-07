package Koha::REST::V1::Acquisitions::FundManagement::SubFunds;

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

use Koha::Acquisition::FundManagement::SubFund;
use Koha::Acquisition::FundManagement::SubFunds;
use Koha::Acquisition::FundManagement::Ledgers;
use Koha::Acquisition::FundManagement::Funds;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sub_funds = $c->objects->search( Koha::Acquisition::FundManagement::SubFunds->new );
        return $c->render( status => 200, openapi => $sub_funds );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $c->param('sub_fund_id') );
        return $c->render_resource_not_found("Sub fund")
            unless $sub_fund;

        $sub_fund->{add_accounting_values} = 1;
        return $c->render( status => 200, openapi => $c->objects->to_api($sub_fund), );
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

                if ( $body->{spend_limit} ) {
                    my $fund   = Koha::Acquisition::FundManagement::Funds->find( $body->{fund_id} );
                    my $result = $fund->is_spend_limit_breached( { new_allocation => $body->{spend_limit} } );
                    return $c->render(
                        status => 400,
                        error  => "Fund spend limit breached, please reduce spend limit by "
                            . $result->{breach_amount}
                            . " or increase the spend limit for this fund"

                    ) unless $result->{within_limit};
                }

                my $sub_fund = Koha::Acquisition::FundManagement::SubFund->new_from_api($body)->store->discard_changes;

                $c->res->headers->location( $c->req->url->to_string . '/' . $sub_fund->sub_fund_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($sub_fund)
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::FundManagement::SubFund object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $c->param('sub_fund_id') );

    unless ($sub_fund) {
        return $c->render(
            status  => 404,
            openapi => { error => "Sub fund not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                delete $body->{lib_groups}   if $body->{lib_groups};
                delete $body->{last_updated} if $body->{last_updated};

                my $error = $sub_fund->verify_updated_fields( { updated_fields => $body } );

                $sub_fund->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $sub_fund->sub_fund_id );
                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($sub_fund)
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::SubFund->new->to_api_mapping;

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

    my $sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $c->param('sub_fund_id') );
    return $c->render_resource_not_found("Sub fund")
        unless $sub_fund;

    return try {
        $sub_fund->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
