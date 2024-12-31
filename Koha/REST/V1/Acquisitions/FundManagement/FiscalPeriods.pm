package Koha::REST::V1::Acquisitions::FundManagement::FiscalPeriods;

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

use Koha::Acquisition::FundManagement::FiscalPeriod;
use Koha::Acquisition::FundManagement::FiscalPeriods;

use C4::Context;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $fiscal_periods = $c->objects->search( Koha::Acquisition::FundManagement::FiscalPeriods->new );
        return $c->render( status => 200, openapi => $fiscal_periods );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $fiscal_period = Koha::Acquisition::FundManagement::FiscalPeriods->find( $c->param('fiscal_period_id') );
        return $c->render_resource_not_found("Fiscal period")
            unless $fiscal_period;

        return $c->render( status => 200, openapi => $c->objects->to_api($fiscal_period), );
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

                my $fiscal_period = Koha::Acquisition::FundManagement::FiscalPeriod->new_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fiscal_period->fiscal_period_id );
                return $c->render(
                    status  => 201,
                    openapi => $c->objects->to_api($fiscal_period)
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::FundManagement::FiscalPeriod object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $fiscal_period = Koha::Acquisition::FundManagement::FiscalPeriods->find( $c->param('fiscal_period_id') );

    unless ($fiscal_period) {
        return $c->render(
            status  => 404,
            openapi => { error => "Fiscal period not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                delete $body->{lib_groups}   if $body->{lib_groups};
                delete $body->{last_updated} if $body->{last_updated};

                $fiscal_period->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fiscal_period->fiscal_period_id );
                return $c->render(
                    status  => 200,
                    openapi => $c->objects->to_api($fiscal_period)
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::FiscalPeriod->new->to_api_mapping;

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

    my $fiscal_period = Koha::Acquisition::FundManagement::FiscalPeriods->find( $c->param('fiscal_period_id') );
    return $c->render_resource_not_found("Fiscal period")
        unless $fiscal_period;

    return try {
        $fiscal_period->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
