package Koha::ILL;

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
use Data::Dumper;

=head1 NAME

Koha::ILL - Koha ILL Object Class

=head1 SYNOPSIS

use Koha::ILL;

my $bldss = Koha::ILL->new($service);

=head1 API

=head2 Class Methods

=cut

# New, Initialises object (with config if given)
=head3 new

=cut

sub new {
    my ( $class, $service ) = @_;
    my $self = {};
    $self->config = {}; #

    bless( $self, $class );
    return $self;
}

# Config, returns config hashref (and allows manipulation of config if passed)
=head3 config

=cut

sub config {
    my ( $self ) = @_;

    return $self->config;
}

# Search, Searches using API
=head3 search

my $results = $bldss->search($query);

=cut

sub search {
    my ( $self, $query ) = @_;

    my $api = BLDSS->new();
    my $reply = $api->search($query);

    my $parser = XML::LibXML->new();
    my $doc = $parser->load_xml( { string => $reply } );

    my @return;
    foreach my $record ( $doc->findnodes('/apiResponse/result/records/record') ) {
       my $response = {};
       for my $property ( $record->findnodes('./*') ) {
            if ( $property->findnodes('*')->size < 1 ) {
                $response->{$property->nodeName()} = $property->textContent();
            }
       }
       for my $metadata ( $record->findnodes('./metadata/*') ) {
           $response->{"metadata"}->{$metadata->nodeName()} = $metadata->textContent();
       }
       push (@return, $response);
    }

    return \@return;
}

# Request, Submits request using API
=head3 request

=cut

sub request {
    my ($self, $request) = @_;

    return 1;
}

# Status, Get status update using API
=head3 status

=cut

sub status {
    my $self = shift;
    my $status;

    return $status;
}

1;
