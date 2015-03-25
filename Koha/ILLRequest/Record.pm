package Koha::ILLRequest::Record;

# Copyright 2013,2014 PTFS Europe Ltd
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
use Koha::Database;

=head1 NAME

Koha::ILLRequest::Record - Koha ILL Record Object

=head1 SYNOPSIS

Object-oriented class providing access to configurable ILL API record
objects.

=head1 DESCRIPTION

This object is used to provide access to API XML results in a
structured fashion.  Its data content is suitable for storing in the
ILL Request Attributes table, and its methods are configurable in
ill/config.yaml.

=head1 API

=head2 Class Methods

=head3 new

    my $record = Koha::ILLRequest::Record->new($config);

Create a new Koha::ILLRequest::Record object, with mapping data loaded from
the ILL configuration file loaded as $CONFIG, and data content derived from
the API's $XML response.

=cut

sub new {
    my ($class, $config) = @_;
    my $self = {
                avail_props   => $config->getProperties('availability'),
                price_props   => $config->getProperties('prices'),
                record_props  => $config->getProperties('record'),
                data          => {},
                accessors     => {},
               };

    bless $self, $class;
    return $self;
}

=head3 checkAvailability

    my $checkAvailability = $illRequest->checkAvailability();

Use our API to check the current availability of this item and return an
associative array in the usual style ready for user output.

TODO: Return a record augmented by its availability status.  Availability is a
transient property, so is not part of the actual record as such.  It is
unclear whether this augmentation should happen here or at ILLRequest level
(where it currently happens via hard-coded values.

=cut

sub checkAvailability {
    my ( $self, $response ) = @_;
    unless ($response) {        # Response is optional, for unit testing.
        $response = Koha::ILLRequest::Abstract->new->checkAvailability($self);
    }
    return $response
        if ( 'HASH' eq ref $response and $response->{status} );
    return $response->result->availability;
}

=head3 checkPrices

    my $prices = $illRequest->checkPrices();

Use our API to return a generic structure on prices, formats, services and
delivery times and return it as a suitably formatted associative array.

=cut

sub checkPrices {
    my ( $self, $response ) = @_;
    unless ($response) {        # Response is optional, for unit testing.
        $response = Koha::ILLRequest::Abstract->new()->getPrices();
    }
    return $response->result;
}

sub _parseResponse {
    my ( $self, $chunk, $config, $accum ) = @_;
    # If clause for unit-testing convenience only. Normally relevant *_props
    # should be passed in $config.
    if ( $config eq "avail" ) {
        $config = ${$self}{avail_props};
    } elsif ( $config eq "price" ) {
        $config = ${$self}{price_props};
    }
    $accum = {} if ( !$accum ); # initiate $accum if empty.
    foreach my $field ( keys $config ) {
        if ( ref(${$config}{$field}) eq 'ARRAY' ) {
            foreach my $node ($chunk->findnodes($field)) {
                ${$accum}{$field} = [] if ( !${$accum}{$field} );
                push @{$accum}{$field},
                  $self->_parseResponse($node, ${$config}{$field}[0], {});
            }
        } else {
            my ( $op, $arg ) = ( "findvalue", $field );
            ( $op, $arg ) = ( "textContent", "" )
              if ( $field eq "./" );
            ${$accum}{$field} =
              {
               value     => $chunk->$op($arg),
               name      => ${$config}{$field}{name},
               inSummary => ${$config}{$field}{inSummary},
              };
            # FIXME: populate accessor if desired.  This breaks the
            # functional-ish approach by referencing $self directly.
            my $accessor = ${$config}{$field}{accessor};
            if ($accessor) {
                ${$self}{accessors}{$accessor} = ${$accum}{$field}{value};
            }
       }
    }
    return $accum;
}

=head3 create_from_xml

    $rec->create_from_xml($xml);

Parse $XML, which should be an API record section, using $REC's configuration.

=cut

sub create_from_xml {
    my ( $self, $xml ) = @_;
    ${$self}{data} = $self->_parseResponse($xml, ${$self}{record_props}, {});
    return $self;
}

=head3 create_from_store

    my $create_from_store = $illRequest->create_from_store($attributes);

Parse $ATTRIBUTES, which should be the result of querying the database for
this Record's intended contents.

=cut

sub create_from_store {
    my ( $self, $attributes ) = @_;

    foreach my $field ( keys ${$self}{record_props} ) {

        # populate data from database
        ${$self}{data}{$field} = {
            value     => $attributes->{$field},
            name      => ${$self}{record_props}{$field}{name},
            inSummary => ${$self}{record_props}{$field}{inSummary},
        };

        # populate accessor if desired
        my $accessor = ${$self}{record_props}{$field}{accessor};
        if ($accessor) {
            ${$self}{accessors}{$accessor} = ${$self}{data}{$field}{value};
        }
    }
    return $self;
}

=head3 getSummary

    $rec->getSummary();

Return a hashref mapping config human names for fields to their
values, if the fields have been defined as 'inSummary' by the yaml
config.

=cut

sub getSummary {
    my $self = shift;
    return $self->_summarize(${$self}{data});
}

=head3 _summarize

    my $_summarize = $illRequest->_summarize();

Extract fields in data structure that are marked for summary, ready for
display in templates.

=cut
sub _summarize {
    my ( $self, $structure) = @_;
    my $accum = {};
    while (my ( $id, $value ) = each $structure) {
        if (ref $value eq 'ARRAY') {
            ${$accum}{$id} = [];
            foreach my $elem (@{$value}) {
                push ${$accum}{$id}, $self->_summarize($elem);
            }
        } elsif (${$value}{name} and ${$value}{inSummary}) {
            ${$accum}{$id} = [ ${$value}{name}, ${$value}{value} ];
        }
    }
    return $accum;
}


=head3 getFullDetails

    $rec->getFullDetails();

Return a hashref mapping config human names for fields to their
values, if the fields have been defined by the yaml config.

=cut

sub getFullDetails {
    my $self = shift;
    my %details;
    foreach my $datum ( keys ${$self}{data} ) {
        my $name = ${$self}{data}{$datum}{name};
        if ($name) {
            $details{$datum} = [ $name, ${$self}{data}{$datum}{value} ];
        }
    }
    return \%details;
}

=head3 getProperty

    $rec->getPoperty(ID);

Return the value of the field identified by the `accessor id' ID,
defined in config.yaml.  If ID does not map to a field, return a
warning message.

=cut

sub getProperty {
    my ($self, $accessor) = @_;
    my $result;
    if (defined ${$self}{accessors}{$accessor}) {
        $result = ${$self}{accessors}{$accessor};
    } else {
        $result = 0;
    }
    return $result;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
