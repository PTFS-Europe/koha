package Koha::ILL::Service;

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
use Koha::ILL::Record;

=head1 NAME

Koha::ILL::Service - Koha ILL Service Class

=head1 SYNOPSIS

use Koha::ILL;

my $service = Koha::ILL::Service->new($config);

=head1 API

=head2 Class Methods

=cut

=head3 new

=cut

sub new {
    my ( $class, $config ) = @_;
    my $self = {};
    ${$self}{config} = $config;

    bless( $self, $class );

    return $self;
}

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
    foreach my $record_data ( $doc->findnodes('/apiResponse/result/records/record') ) {
        my $record = Koha::ILL::Record->new(${$self}{config})->create_from_xml($record_data);
        push (@return, $record);
    }

    return \@return;
}

=head3 submit

my $results = $bldss->submit($request);

=cut

sub submit {
    my ( $self, $request ) = @_;

    my $api = BLDSS->new();

    return;
}

=head3 update

my $results = $bldss->update($request);

=cut

sub update {
    my ( $self, $request ) = @_;

    my $api = BLDSS->new();

    return;
}

1;
