package Koha::REST::V1::ERM::CounterFiles;

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

use Koha::ERM::CounterFiles;

use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $counter_files_set = Koha::ERM::CounterFiles->new;
        my $counter_files = $c->objects->search( $counter_files_set );
        return $c->render( status => 200, openapi => $counter_files );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

Controller function that handles retrieving a single Koha::ERM::CounterFile object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $counter_file_id = $c->validation->param('erm_counter_files_id');
        my $counter_file    = $c->objects->find( Koha::ERM::CounterFiles->search, $counter_file_id );

        unless ($counter_file) {
            return $c->render(
                status  => 404,
                openapi => { error => "Counter file not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $counter_file
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::ERM::CounterFile object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                my $counter_file = Koha::ERM::CounterFile->new_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $counter_file->erm_counter_files_id);
                return $c->render(
                    status  => 201,
                    openapi => $counter_file->to_api
                );
            }
        );
    }
    catch {

        my $to_api_mapping = Koha::ERM::CounterFile->new->to_api_mapping;

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

Controller function that handles updating a Koha::ERM::CounterFile object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $counter_file_id = $c->validation->param('erm_counter_files_id');
    my $counter_file = Koha::ERM::CounterFiles->find( $counter_file_id );

    unless ($counter_file) {
        return $c->render(
            status  => 404,
            openapi => { error => "Counter file not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                $counter_file->set_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $counter_file->erm_counter_files_id);
                return $c->render(
                    status  => 200,
                    openapi => $counter_file->to_api
                );
            }
        );
    }
    catch {
        my $to_api_mapping = Koha::ERM::CounterFile->new->to_api_mapping;

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

    my $counter_file_id = $c->validation->param('erm_counter_files_id');
    my $counter_file = Koha::ERM::CounterFiles->find( $counter_file_id );
    unless ($counter_file) {
        return $c->render(
            status  => 404,
            openapi => { error => "Counter file not found" }
        );
    }

    return try {
        $counter_file->delete;
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
