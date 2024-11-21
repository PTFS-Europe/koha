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

use Koha::REST::V1::Acquisitions::FundManagement::Util;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $sub_funds_set = Koha::Acquisition::FundManagement::SubFunds->new;
        my $sub_funds     = $c->objects->search($sub_funds_set);

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
        my $sub_funds_set = Koha::Acquisition::FundManagement::SubFunds->new;
        my $sub_fund      = $c->objects->find( $sub_funds_set, $c->param('id') );

        unless ($sub_fund) {
            return $c->render(
                status  => 404,
                openapi => { error => "Sub fund not found" }
            );
        }

        $sub_fund = Koha::REST::V1::Acquisitions::FundManagement::Util->add_accounting_values( { data => $sub_fund } );

        return $c->render(
            status  => 200,
            openapi => $sub_fund
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

                my $sub_fund = Koha::Acquisition::FundManagement::SubFund->new_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $sub_fund->sub_fund_id );
                return $c->render(
                    status  => 201,
                    openapi => $sub_fund->to_api
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

    my $sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $c->param('id') );

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

                $sub_fund->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $sub_fund->sub_fund_id );
                return $c->render(
                    status  => 200,
                    openapi => $sub_fund->to_api
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

    my $sub_fund = Koha::Acquisition::FundManagement::SubFunds->find( $c->param('id') );
    unless ($sub_fund) {
        return $c->render(
            status  => 404,
            openapi => { error => "Sub fund not found" }
        );
    }

    return try {
        $sub_fund->delete;
        return $c->render(
            status  => 204,
            openapi => q{}
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
