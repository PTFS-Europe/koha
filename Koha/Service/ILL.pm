package Koha::Service::ILL;

# This file is part of Koha.
#
# Copyright 2007 LibLime
# Copyright 2012 software.coop and MJ Ray
# Copyright (C) 2014 ByWater Solutions
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

use base 'Koha::Service';

use Koha::ILL;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { },
        routes => [
            [ qr'GET /', 'search' ],
            [ qr'POST /', 'request' ],
        ]
    } );
}

sub search {
    my ( $self ) = @_;

    my $query = $self->query->param('query');
    my $reply = [];

    my $bldss = Koha::ILL->new();
    my $results = $bldss->search($query);
    foreach my $rec ( @{$results} ) {
        push @{$reply}, { "title" => $rec->getTitle(), "author" => $rec->getAuthor(), "id" => $rec->getID() };
    }

    $self->output( $reply, { status => '200 OK', type => 'json' } );
    return;
}

sub request {
    my ( $self ) = @_;

    my $result = {};
    my $postdata = $self->query->param('POSTDATA');
}

1;
