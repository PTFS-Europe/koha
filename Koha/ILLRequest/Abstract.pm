package Koha::ILLRequest::Abstract;

# Copyright PTFS Europe 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;

use BLDSS;
use XML::LibXML;
use Koha::ILLRequest::XML::BLDSS;
use Koha::ILLRequest::Record;
use Koha::ILLRequest::Status;
use Koha::ILLRequest::Config;

=head1 NAME

Koha::ILLRequest::Abstract - Koha ILL AbstractILL Object class

=head1 SYNOPSIS

=head1 DESCRIPTION

In theory, this class is to act as a layer in between individual means for
communicating with ILL APIs and other objects.

=head1 API

=head2 Class Methods

=cut

=head3 new

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {};

    # This is where we may want to introduce the possibility to choose amongst
    # backends.
    ${$self}{config} = Koha::ILLRequest::Config->new();
    my $creds = $self->{config}->getCredentials($params->{branch});
    $self->{api} = BLDSS->new( $creds );

    bless( $self, $class );
    return $self;
}

sub build {
    my ( $self, $attributes ) = @_;

    my $record = Koha::ILLRequest::Record->new(${$self}{config})
      ->create_from_store($attributes);
    my $status = Koha::ILLRequest::Status->new()->create_from_store($attributes);

    return { record => $record, status => $status };
}

=head3 checkAvailability

    my $checkAvailability = $illRequest->checkAvailability($uin, $properties);

Submit a request to the currently configured API for $UIN, supplemented with
the hashref $PROPERTIES.  Return the API response as an HTML object.

=cut

sub checkAvailability {
    my ( $self, $uin, $properties ) = @_;
    my $reply  = ${$self}{api}->availability($uin, $properties);
    if (!$reply) {
        return 0;
    }
    return Koha::ILLRequest::XML::BLDSS->new
      ->load_xml( { string => $reply } );
}

=head3 getPrices

    my $getPrices = $illRequest->getPrices();

Return an array containing pricing information for the API in use.

=cut

sub getPrices {
    my ( $self ) = @_;

    my $prices = ${$self}{api}->prices;
    return Koha::ILLRequest::XML::BLDSS->new->load_xml( { string => $prices } );
}

=head3 search

    my $results = $abstractILL->search($query);

Return an array of Record objects created from this AbstractILL's config and
the output of querying the API in use.

The optional OPTS parameter specifies additional options to be passed to the
API. For now the options we use in the ILL Module are:
 max_results -> SearchRequest.maxResults,
 start_rec   -> SearchRequest.start,
 isbn        -> SearchRequest.Advanced.isbn
 issn        -> SearchRequest.Advanced.issn
 title       -> SearchRequest.Advanced.title
 author      -> SearchRequest.Advanced.author
 type        -> SearchRequest.Advanced.type
 general     -> SearchRequest.Advanced.general

We simply pass the options hashref straight to the API library.

=cut

sub search {
    my ( $self, $query, $opts ) = @_;

    my $reply = ${$self}{api}->search($query, $opts);

    if (!$reply) {
        return 0;
    }

    my $parser = XML::LibXML->new();
    my $doc = $parser->load_xml( { string => $reply } );

    my @return;
    foreach my $datum ( $doc->findnodes('/apiResponse/result/records/record') ) {
        my $record =
          Koha::ILLRequest::Record->new(${$self}{config})
            ->create_from_xml($datum);
        push (@return, $record);
    }

    return \@return;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
