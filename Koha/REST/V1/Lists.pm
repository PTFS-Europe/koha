package Koha::REST::V1::Lists;

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
use Koha::Virtualshelves;
use Try::Tiny qw( catch try );

use Data::Dumper;

=head1 API

=head2 Methods

=head3 add

Create a virtual shelf

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {

        # Check if owner_id exists if provided
        my $body = $c->req->json;
        if ( $body->{owner_id} ) {
            my $owner = Koha::Patrons->find( $body->{owner_id} );
            unless ($owner) {
                return $c->render(
                    status  => 400,
                    openapi => {
                        error      => "Invalid owner_id",
                        error_code => "invalid_owner"
                    }
                );
            }
        }

        # Set allow_change_from_staff=1 by default unless specified
        $body->{allow_change_from_staff} = 1 unless exists $body->{allow_change_from_staff};

        my $list = Koha::Virtualshelf->new_from_api($body);
        $list->store->discard_changes;

        $c->res->headers->location( $c->req->url->to_string . '/' . $list->id );

        return $c->render(
            status  => 201,
            openapi => $list->to_api
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

Update a virtual shelf

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $list = Koha::Virtualshelves->find( $c->param('list_id') );

    return $c->render_resource_not_found("List")
        unless $list;

    my $user = $c->stash('koha.user');

    # Check if the list does not belong to the user
    if ( $list->owner != $user->id ) {

        # Check if the user is allowed to modify the list
        unless ( $list->allow_change_from_others || $list->allow_change_from_staff ) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Cannot modify list without proper permissions",
                    error_code => "forbidden"
                }
            );
        }
    }

    # Check allow_change_from_owner for own lists
    if ( $list->owner == $user->id && $list->allow_change_from_owner == 0 ) {
        return $c->render(
            status  => 403,
            openapi => {
                error      => "Forbidden - list cannot be modified",
                error_code => "forbidden"
            }
        );
    }

    return try {
        $list->set_from_api( $c->req->json );
        $list->store();

        return $c->render(
            status  => 200,
            openapi => $list->to_api
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a virtual shelf if it exists

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $list = Koha::Virtualshelves->find( $c->param('list_id') );

    return $c->render_resource_not_found("List")
        unless $list;

    my $user = $c->stash('koha.user');

    # Check if the list does not belong to the user
    if ( $list->owner != $user->id ) {

        # Check if the user is allowed to delete the list
        unless ( $list->allow_change_from_others || $list->allow_change_from_staff ) {
            return $c->render(
                status  => 403,
                openapi => {
                    error      => "Forbidden - you are not allowed to delete this list",
                    error_code => "forbidden"
                }
            );
        }
    }

    return try {
        $list->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list_public

=cut

sub list_public {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');

    my $only_mine   = $c->param('only_mine');
    my $only_public = $c->param('only_public');

    $c->req->params->remove('only_mine')->remove('only_public');

    if ( !$user && $only_mine ) {
        return $c->render(
            status  => 400,
            openapi => {
                error      => "Bad request - only_mine can only be passed by logged in users",
                error_code => "only_mine_forbidden",
            },
        );
    }

    return try {

        my $lists_set = Koha::Virtualshelves->new;

        if ($only_mine) {
            $lists_set = $lists_set->search( { owner => $user->id } );
        }

        if ( $only_public || !$user ) {
            $lists_set = $lists_set->filter_by_public;
        } else {
            $lists_set = $lists_set->filter_by_readable( { patron_id => $user->id } );
        }

        return $c->render(
            status  => 200,
            openapi => $c->objects->search($lists_set),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}
1;
