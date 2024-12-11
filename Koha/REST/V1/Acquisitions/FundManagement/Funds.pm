package Koha::REST::V1::Acquisitions::FundManagement::Funds;

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

use Koha::Acquisition::FundManagement::Fund;
use Koha::Acquisition::FundManagement::Funds;
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
        my $funds_set = Koha::Acquisition::FundManagement::Funds->new;
        my $funds     = $c->objects->search($funds_set);

        return $c->render( status => 200, openapi => $funds );
    } catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $funds_set = Koha::Acquisition::FundManagement::Funds->new;
        my $fund      = $c->objects->find( $funds_set, $c->param('fund_id') );

        unless ($fund) {
            return $c->render(
                status  => 404,
                openapi => { error => "Fund not found" }
            );
        }

        $fund = Koha::REST::V1::Acquisitions::FundManagement::Util->add_accounting_values( { data => $fund } );

        return $c->render(
            status  => 200,
            openapi => $fund
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

                $body = _inherit_currency_and_owner($body);

                my $fund = Koha::Acquisition::FundManagement::Fund->new_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fund->fund_id );
                return $c->render(
                    status  => 201,
                    openapi => $fund->to_api
                );
            }
        );
    } catch {
        return $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::Acquisition::FundManagement::Fund object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $fund = Koha::Acquisition::FundManagement::Funds->find( $c->param('fund_id') );

    unless ($fund) {
        return $c->render(
            status  => 404,
            openapi => { error => "Fund not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->req->json;

                delete $body->{lib_groups}   if $body->{lib_groups};
                delete $body->{last_updated} if $body->{last_updated};

                $body = _inherit_currency_and_owner($body);

                $fund->set_from_api($body)->store;

                $c->res->headers->location( $c->req->url->to_string . '/' . $fund->fund_id );
                return $c->render(
                    status  => 200,
                    openapi => $fund->to_api
                );
            }
        );
    } catch {
        my $to_api_mapping = Koha::Acquisition::FundManagement::Fund->new->to_api_mapping;

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

    my $fund = Koha::Acquisition::FundManagement::Funds->find( $c->param('fund_id') );
    unless ($fund) {
        return $c->render(
            status  => 404,
            openapi => { error => "Fund not found" }
        );
    }

    return try {
        $fund->delete;
        return $c->render(
            status  => 204,
            openapi => q{}
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_fund_group

=cut

sub get_fund_group {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $funds_set = Koha::Acquisition::FundManagement::Funds->new;
        my $funds     = $c->objects->search($funds_set);

        my @combined_fund_allocations = ();

        my $group_name;
        foreach my $fund (@$funds) {
            push( @combined_fund_allocations, @{ $fund->fund_allocations } );
            $group_name = $fund->fund_group if !$group_name;
        }

        my $combined_fund_data = {
            name             => $group_name,
            fund_allocations => \@combined_fund_allocations,
            currency         => 'GBP'                          # FIXME: How do we handle currencies in groups?
        };

        my $fund_group =
            Koha::REST::V1::Acquisitions::FundManagement::Util->add_accounting_values(
            { data => $combined_fund_data } );

        return $c->render( status => 200, openapi => $fund_group );
    } catch {
        $c->unhandled_exception($_);
    };

}

sub _inherit_currency_and_owner {
    my ($fund) = @_;

    my $ledger = Koha::Acquisition::FundManagement::Ledgers->find( { ledger_id => $fund->{ledger_id} } );

    $fund->{currency} = $ledger->currency;
    $fund->{owner_id} = $ledger->owner_id;

    return $fund;
}

1;
