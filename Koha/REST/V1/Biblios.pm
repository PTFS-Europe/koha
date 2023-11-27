package Koha::REST::V1::Biblios;

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

use Koha::Biblios;
use Koha::Ratings;
use Koha::RecordProcessor;
use C4::Biblio qw( DelBiblio AddBiblio ModBiblio );
use C4::Search qw( FindDuplicate );

use C4::Barcodes::ValueBuilder;
use C4::Context;

use Koha::Items;

use List::MoreUtils qw( any );
use MARC::Record::MiJ;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 get

Controller function that handles retrieving a single biblio object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $attributes;
    $attributes = { prefetch => [ 'metadata' ] } # don't prefetch metadata if not needed
        unless $c->req->headers->accept =~ m/application\/json/;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->validation->param('biblio_id') }, $attributes );

    unless ( $biblio ) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    return try {

        if ( $c->req->headers->accept =~ m/application\/json/ ) {
            return $c->render(
                status => 200,
                json   => $biblio->to_api
            );
        }
        else {
            my $metadata = $biblio->metadata;
            my $record   = $metadata->record;
            my $schema   = $metadata->schema // C4::Context->preference("marcflavour");

            $c->respond_to(
                marcxml => {
                    status => 200,
                    format => 'marcxml',
                    text   => $record->as_xml_record($schema),
                },
                mij => {
                    status => 200,
                    format => 'mij',
                    data   => $record->to_mij
                },
                marc => {
                    status => 200,
                    format => 'marc',
                    text   => $record->as_usmarc
                },
                txt => {
                    status => 200,
                    format => 'text/plain',
                    text   => $record->as_formatted
                },
                any => {
                    status  => 406,
                    openapi => [
                        "application/json",
                        "application/marcxml+xml",
                        "application/marc-in-json",
                        "application/marc",
                        "text/plain"
                    ]
                }
            );
        }
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller function that handles deleting a biblio object

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->validation->param('biblio_id') );

    if ( not defined $biblio ) {
        return $c->render(
            status  => 404,
            openapi => { error => "Object not found" }
        );
    }

    return try {
        my $error = DelBiblio( $biblio->id );

        if ($error) {
            return $c->render(
                status  => 409,
                openapi => { error => $error }
            );
        }
        else {
            return $c->render( status => 204, openapi => "" );
        }
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_public

Controller function that handles retrieving a single biblio object

=cut

sub get_public {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find(
        { biblionumber => $c->validation->param('biblio_id') },
        { prefetch     => ['metadata'] } );

    unless ($biblio) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    return try {

        my $metadata = $biblio->metadata;
        my $record   = $metadata->record;

        my $opachiddenitems_rules = C4::Context->yaml_preference('OpacHiddenItems');
        my $patron = $c->stash('koha.user');

        # Check if the biblio should be hidden for unprivileged access
        # unless there's a logged in user, and there's an exception for it's
        # category
        unless ( $patron and $patron->category->override_hidden_items ) {
            if ( $biblio->hidden_in_opac({ rules => $opachiddenitems_rules }) )
            {
                return $c->render(
                    status  => 404,
                    openapi => {
                        error => "Object not found."
                    }
                );
            }
        }

        my $schema = $metadata->schema // C4::Context->preference("marcflavour");

        my $record_processor = Koha::RecordProcessor->new({
            filters => 'ViewPolicy',
            options => {
                interface => 'opac',
                frameworkcode => $biblio->frameworkcode
            }
        });
        # Apply framework's filtering to MARC::Record object
        $record_processor->process($record);

        $c->respond_to(
            marcxml => {
                status => 200,
                format => 'marcxml',
                text   => $record->as_xml_record($schema),
            },
            mij => {
                status => 200,
                format => 'mij',
                data   => $record->to_mij
            },
            marc => {
                status => 200,
                format => 'marc',
                text   => $record->as_usmarc
            },
            txt => {
                status => 200,
                format => 'text/plain',
                text   => $record->as_formatted
            },
            any => {
                status  => 406,
                openapi => [
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc",
                    "text/plain"
                ]
            }
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_bookings

Controller function that handles retrieving biblio's bookings

=cut

sub get_bookings {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->param('biblio_id') }, { prefetch => ['bookings'] } );

    unless ( $biblio ) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    return try {

        my $bookings_rs = $biblio->bookings;
        my $bookings    = $c->objects->search( $bookings_rs );
        return $c->render(
            status  => 200,
            openapi => $bookings
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_items

Controller function that handles retrieving biblio's items

=cut

sub get_items {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->param('biblio_id') }, { prefetch => ['items'] } );
    my $bookable_only = $c->param('bookable');

    unless ( $biblio ) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    return try {

        my $items_rs = $biblio->items;
        $items_rs = $items_rs->filter_by_bookable if $bookable_only;
        my $items    = $c->objects->search( $items_rs );
        return $c->render(
            status  => 200,
            openapi => $items
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_checkouts

List Koha::Checkout objects

=cut

sub get_checkouts {
    my $c = shift->openapi->valid_input or return;

    my $checked_in = delete $c->validation->output->{checked_in};

    try {
        my $biblio = Koha::Biblios->find( $c->validation->param('biblio_id') );

        unless ($biblio) {
            return $c->render(
                status  => 404,
                openapi => { error => 'Object not found' }
            );
        }

        my $checkouts =
          ($checked_in)
          ? $c->objects->search( $biblio->old_checkouts )
          : $c->objects->search( $biblio->current_checkouts );

        return $c->render(
            status  => 200,
            openapi => $checkouts
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 pickup_locations

Method that returns the possible pickup_locations for a given biblio
used for building the dropdown selector

=cut

sub pickup_locations {
    my $c = shift->openapi->valid_input or return;

    my $biblio_id = $c->validation->param('biblio_id');
    my $biblio = Koha::Biblios->find( $biblio_id );

    unless ($biblio) {
        return $c->render(
            status  => 404,
            openapi => { error => "Biblio not found" }
        );
    }

    my $patron_id = delete $c->validation->output->{patron_id};
    my $patron    = Koha::Patrons->find( $patron_id );

    unless ($patron) {
        return $c->render(
            status  => 400,
            openapi => { error => "Patron not found" }
        );
    }

    return try {

        my $pl_set = $biblio->pickup_locations( { patron => $patron } );

        my @response = ();
        if ( C4::Context->preference('AllowHoldPolicyOverride') ) {

            my $libraries_rs = Koha::Libraries->search( { pickup_location => 1 } );
            my $libraries    = $c->objects->search($libraries_rs);

            @response = map {
                my $library = $_;
                $library->{needs_override} = (
                    any { $_->branchcode eq $library->{library_id} }
                    @{$pl_set->as_list}
                  )
                  ? Mojo::JSON->false
                  : Mojo::JSON->true;
                $library;
            } @{$libraries};
        }
        else {

            my $pickup_locations = $c->objects->search($pl_set);
            @response = map { $_->{needs_override} = Mojo::JSON->false; $_; } @{$pickup_locations};
        }

        return $c->render(
            status  => 200,
            openapi => \@response
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get_items_public

Controller function that handles retrieving biblio's items, for unprivileged
access.

=cut

sub get_items_public {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( { biblionumber => $c->validation->param('biblio_id') }, { prefetch => ['items'] } );

    unless ( $biblio ) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    return try {

        my $patron = $c->stash('koha.user');

        my $items_rs = $biblio->items->filter_by_visible_in_opac({ patron => $patron });
        my $items    = $c->objects->search( $items_rs );
        return $c->render(
            status  => 200,
            openapi => $items
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 set_rating

Set rating for the logged in user

=cut


sub set_rating {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find( $c->validation->param('biblio_id') );

    unless ($biblio) {
        return $c->render(
            status  => 404,
            openapi => {
                error => "Object not found."
            }
        );
    }

    my $patron = $c->stash('koha.user');
    unless ($patron) {
        return $c->render(
            status => 403,
            openapi =>
                { error => "Cannot rate. Reason: must be logged-in" }
        );
    }

    my $body   = $c->validation->param('body');
    my $rating_value = $body->{rating};

    return try {

        my $rating = Koha::Ratings->find(
            {
                biblionumber   => $biblio->biblionumber,
                borrowernumber => $patron->borrowernumber,
            }
        );
        $rating->delete if $rating;

        if ( $rating_value ) { # Cannot set to 0 from the UI
            $rating = Koha::Rating->new(
                {
                    biblionumber   => $biblio->biblionumber,
                    borrowernumber => $patron->borrowernumber,
                    rating_value   => $rating_value,
                }
            )->store;
        };
        my $ratings =
          Koha::Ratings->search( { biblionumber => $biblio->biblionumber } );
        my $average = $ratings->get_avg_rating;

        return $c->render(
            status  => 200,
            openapi => {
                rating  => $rating && $rating->in_storage ? $rating->rating_value : undef,
                average => $average,
                count   => $ratings->count
            },
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles creating a biblio object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    try {
        my $headers = $c->req->headers;

        my $flavour = $headers->header('x-record-schema');
        $flavour //= C4::Context->preference('marcflavour');

        my $record;

        my $frameworkcode = $headers->header('x-framework-id');
        my $content_type  = $headers->content_type;

        if ( $content_type =~ m/application\/marcxml\+xml/ ) {
            $record = MARC::Record->new_from_xml( $c->req->body, 'UTF-8', $flavour );
        }
        elsif ( $content_type =~ m/application\/marc-in-json/ ) {
            $record = MARC::Record->new_from_mij_structure( $c->req->json );
        }
        elsif ( $content_type =~ m/application\/marc/ ) {
            $record = MARC::Record->new_from_usmarc( $c->req->body );
        }
        else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc"
                ]
            );
        }

        my ( $duplicatebiblionumber, $duplicatetitle );
            ( $duplicatebiblionumber, $duplicatetitle ) = FindDuplicate($record);

        my $confirm_not_duplicate = $headers->header('x-confirm-not-duplicate');

        return $c->render(
            status  => 400,
            openapi => {
                error => "Duplicate biblio $duplicatebiblionumber",
            }
        ) unless !$duplicatebiblionumber || $confirm_not_duplicate;

        my ( $biblionumber, $oldbibitemnum );
            ( $biblionumber, $oldbibitemnum ) = AddBiblio( $record, $frameworkcode );

        $c->render(
            status  => 200,
            openapi => { id => $biblionumber }
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

Controller function that handles modifying an biblio object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $biblio_id = $c->param('biblio_id');
    my $biblio    = Koha::Biblios->find($biblio_id);

    if ( ! defined $biblio ) {
        return $c->render(
            status  => 404,
            openapi => { error => "Object not found" }
        );
    }

    try {
        my $headers = $c->req->headers;

        my $flavour = $headers->header('x-record-schema');
        $flavour //= C4::Context->preference('marcflavour');

        my $frameworkcode = $headers->header('x-framework-id') || $biblio->frameworkcode;

        my $content_type = $headers->content_type;

        my $record;

        if ( $content_type =~ m/application\/marcxml\+xml/ ) {
            $record = MARC::Record->new_from_xml( $c->req->body, 'UTF-8', $flavour );
        }
        elsif ( $content_type =~ m/application\/marc-in-json/ ) {
            $record = MARC::Record->new_from_mij_structure( $c->req->json );
        }
        elsif ( $content_type =~ m/application\/marc/ ) {
            $record = MARC::Record->new_from_usmarc( $c->req->body );
        }
        else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/json",
                    "application/marcxml+xml",
                    "application/marc-in-json",
                    "application/marc"
                ]
            );
        }

        ModBiblio( $record, $biblio_id, $frameworkcode );

        $c->render(
            status  => 200,
            openapi => { id => $biblio_id }
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 list

Controller function that handles retrieving a single biblio object

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    my @prefetch = qw(biblioitem);
    push @prefetch, 'metadata'    # don't prefetch metadata if not needed
      unless $c->req->headers->accept =~ m/application\/json/;

    my $rs = Koha::Biblios->search( undef, { prefetch => \@prefetch });
    my $biblios = $c->objects->search_rs( $rs, [(sub{ $rs->api_query_fixer( $_[0], '', $_[1] ) })] );

    return try {

        if ( $c->req->headers->accept =~ m/application\/json(;.*)?$/ ) {
            return $c->render(
                status => 200,
                json   => $c->objects->to_api( $biblios ),
            );
        }
        elsif (
            $c->req->headers->accept =~ m/application\/marcxml\+xml(;.*)?$/ )
        {
            $c->res->headers->add( 'Content-Type', 'application/marcxml+xml' );
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('marcxml')
            );
        }
        elsif (
            $c->req->headers->accept =~ m/application\/marc-in-json(;.*)?$/ )
        {
            $c->res->headers->add( 'Content-Type', 'application/marc-in-json' );
            return $c->render(
                status => 200,
                data   => $biblios->print_collection('mij')
            );
        }
        elsif ( $c->req->headers->accept =~ m/application\/marc(;.*)?$/ ) {
            $c->res->headers->add( 'Content-Type', 'application/marc' );
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('marc')
            );
        }
        elsif ( $c->req->headers->accept =~ m/text\/plain(;.*)?$/ ) {
            return $c->render(
                status => 200,
                text   => $biblios->print_collection('txt')
            );
        }
        else {
            return $c->render(
                status  => 406,
                openapi => [
                    "application/json",         "application/marcxml+xml",
                    "application/marc-in-json", "application/marc",
                    "text/plain"
                ]
            );
        }
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
