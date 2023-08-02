package Koha::REST::V1::ERM::UsageTitles;

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
use Module::Load qw( load );

use Koha::ERM::UsageTitles;
use Koha::ERM::UsagePlatforms;
use Koha::ERM::UsageItems;
use Koha::ERM::UsageDatabases;
use Koha::ERM::UsageDataProvider;
use Koha::ERM::UsageDataProviders;

use Clone qw( clone );
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );
use JSON;

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $usage_titles_set = Koha::ERM::UsageTitles->new;
        my $usage_titles = $c->objects->search( $usage_titles_set );
        return $c->render( status => 200, openapi => $usage_titles );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller function that handles retrieving a single Koha::ERM::UsageTitle object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $usage_title_id = $c->validation->param('erm_usage_title_id');
        my $usage_title    = $c->objects->find( Koha::ERM::UsageTitles->search, $usage_title_id );

        unless ($usage_title) {
            return $c->render(
                status  => 404,
                openapi => { error => "Usage title not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $usage_title
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::ERM::UsageTitle object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                my $usage_title = Koha::ERM::UsageTitle->new_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $usage_title->title_id);
                return $c->render(
                    status  => 201,
                    openapi => $usage_title->to_api
                );
            }
        );
    }
    catch {

        my $to_api_mapping = Koha::ERM::UsageTitle->new->to_api_mapping;

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

Controller function that handles updating a Koha::ERM::UsageTitle object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $usage_title_id = $c->validation->param('erm_usage_title_id');
    my $usage_title = Koha::ERM::UsageTitles->find( $usage_title_id );

    unless ($usage_title) {
        return $c->render(
            status  => 404,
            openapi => { error => "Usage title not found" }
        );
    }

    return try {
        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                $usage_title->set_from_api($body)->store;

                $c->res->headers->location($c->req->url->to_string . '/' . $usage_title->title_id);
                return $c->render(
                    status  => 200,
                    openapi => $usage_title->to_api
                );
            }
        );
    }
    catch {
        my $to_api_mapping = Koha::ERM::UsageTitle->new->to_api_mapping;

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

    my $usage_title_id = $c->validation->param('erm_usage_title_id');
    my $usage_title = Koha::ERM::UsageTitles->find( $usage_title_id );
    unless ($usage_title) {
        return $c->render(
            status  => 404,
            openapi => { error => "Usage title not found" }
        );
    }

    return try {
        $usage_title->delete;
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
