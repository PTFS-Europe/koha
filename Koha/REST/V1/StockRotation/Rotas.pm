package Koha::REST::V1::StockRotation::Rotas;

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

use Koha::StockRotationRotas;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $rotas = $c->objects->search( Koha::StockRotationRotas->new );
        return $c->render( status => 200, openapi => $rotas );
    }
    catch {
        $c->unhandled_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $rota = Koha::StockRotationRotas->find( $c->param('rota_id') );
        unless ($rota) {
            return $c->render( status  => 404,
                            openapi => { error => "Rota not found" } );
        }

        return $c->render( status => 200, openapi => $rota->to_api );
    }
    catch {
        $c->unhandled_exception($_);
    }
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $rota = Koha::StockRotationRota->new_from_api( $c->req->json );
        $rota->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $rota->rotaid );
        return $c->render(
            status  => 201,
            openapi => $rota->to_api
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $rota = Koha::StockRotationRotas->find( $c->param('rota_id') );

    if ( not defined $rota ) {
        return $c->render( status  => 404,
                           openapi => { error => "Object not found" } );
    }

    return try {
        $rota->set_from_api( $c->req->json );
        $rota->store();
        return $c->render( status => 200, openapi => $rota->to_api );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $rota = Koha::StockRotationRotas->find( $c->param('rota_id') );
    if ( not defined $rota ) {
        return $c->render( status  => 404,
                           openapi => { error => "Object not found" } );
    }

    return try {
        $rota->delete;
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
