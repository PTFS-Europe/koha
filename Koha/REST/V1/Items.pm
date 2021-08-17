package Koha::REST::V1::Items;

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

use Koha::Items;

use Try::Tiny;

=head1 NAME

Koha::REST::V1::Items - Koha REST API for handling items (V1)

=head1 API

=head2 Methods

=cut

=head3 list

Controller function that handles listing Koha::Item objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $items_set = Koha::Items->new;
        my $items     = $c->objects->search( $items_set );
        return $c->render(
            status  => 200,
            openapi => $items
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}


=head3 get

Controller function that handles retrieving a single Koha::Item

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    try {
        my $item = Koha::Items->find($c->validation->param('item_id'));
        unless ( $item ) {
            return $c->render(
                status => 404,
                openapi => { error => 'Item not found'}
            );
        }
        return $c->render( status => 200, openapi => $item->to_api );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 bundled_items

Controller function that handles bundled_items Koha::Item objects

=cut

sub bundled_items {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->validation->param('item_id');
    my $item = Koha::Items->find( $item_id );

    unless ($item) {
        return $c->render(
            status  => 404,
            openapi => { error => "Item not found" }
        );
    }

    return try {
        my $items_set = $item->bundle_items;
        my $items     = $c->objects->search( $items_set );
        return $c->render(
            status  => 200,
            openapi => $items
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add_to_bundle

Controller function that handles adding items to this bundle

=cut

sub add_to_bundle {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->validation->param('item_id');
    my $item = Koha::Items->find( $item_id );

    unless ($item) {
        return $c->render(
            status  => 404,
            openapi => { error => "Item not found" }
        );
    }


    my $bundle_item_id = $c->validation->param('body')->{'external_id'};
    my $bundle_item = Koha::Items->find( { barcode => $bundle_item_id } );

    unless ($bundle_item) {
        return $c->render(
            status  => 404,
            openapi => { error => "Bundle item not found" }
        );
    }

    return try {
        my $link = $item->add_to_bundle($bundle_item);
        return $c->render(
            status  => 201,
            openapi => $bundle_item
        );
    }
    catch {
        if ( ref($_) eq 'Koha::Exceptions::Object::DuplicateID' ) {
            return $c->render(
                status  => 409,
                openapi => {
                    error => 'Item is already bundled',
                    key   => $_->duplicate_id
                }
            );
        }
        else {
            $c->unhandled_exception($_);
        }
    };
}

=head3 remove_from_bundle

Controller function that handles removing items from this bundle

=cut

sub remove_from_bundle {
    my $c = shift->openapi->valid_input or return;

    my $item_id = $c->validation->param('item_id');
    my $item = Koha::Items->find( $item_id );

    unless ($item) {
        return $c->render(
            status  => 404,
            openapi => { error => "Item not found" }
        );
    }

    my $bundle_item_id = $c->validation->param('bundled_item_id');
    my $bundle_item = Koha::Items->find( { itemnumber => $bundle_item_id } );

    unless ($bundle_item) {
        return $c->render(
            status  => 404,
            openapi => { error => "Bundle item not found" }
        );
    }

    $bundle_item->remove_from_bundle;
    return $c->render(
        status  => 204,
    );
}

1;
