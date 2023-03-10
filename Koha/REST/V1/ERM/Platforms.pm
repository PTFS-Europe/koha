package Koha::REST::V1::ERM::Platforms;

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

use Koha::ERM::Platforms;

use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $platforms_set = Koha::ERM::Platforms->new;
        my $platforms = $c->objects->search( $platforms_set );
        return $c->render( status => 200, openapi => $platforms );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

Controller function that handles retrieving a single Koha::ERM::Platform object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $platform_id = $c->validation->param('erm_platform_id');
        my $platform    = $c->objects->find( Koha::ERM::Platforms->search, $platform_id );

        unless ($platform) {
            return $c->render(
                status  => 404,
                openapi => { error => "Platform not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $platform
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::ERM::Platform object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                my $platform = Koha::ERM::Platform->new_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $platform->erm_platform_id);
                return $c->render(
                    status  => 201,
                    openapi => $platform->to_api
                );
            }
        );
    }
    catch {

        my $to_api_mapping = Koha::ERM::Platform->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => $_->error, conflict => $_->duplicate_id }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->broken_fk }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->parameter }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles updating a Koha::ERM::Platform object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $platform_id = $c->validation->param('erm_platform_id');
    my $platform = Koha::ERM::Platforms->find( $platform_id );

    unless ($platform) {
        return $c->render(
            status  => 404,
            openapi => { error => "Platform not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                $platform->set_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $platform->erm_platform_id);
                return $c->render(
                    status  => 200,
                    openapi => $platform->to_api
                );
            }
        );
    }
    catch {
        my $to_api_mapping = Koha::ERM::Platform->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->broken_fk }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->parameter }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::PayloadTooLarge') ) {
                return $c->render(
                    status  => 413,
                    openapi => { error => $_->error }
                );
            }
        }

        $c->unhandled_exception($_);
    };
};

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $platform_id = $c->validation->param('erm_platform_id');
    my $platform = Koha::ERM::Platforms->find( $platform_id );
    unless ($platform) {
        return $c->render(
            status  => 404,
            openapi => { error => "Platform not found" }
        );
    }

    return try {
        $platform->delete;
        return $c->render(
            status  => 204,
            openapi => q{}
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
