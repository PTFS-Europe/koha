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
transient property, so is not part of the actual record as such.

=cut

sub checkAvailability {
    my ( $self, $xml ) = @_;
    if ( !$xml ) {
        # If $xml is not supplied, then we create it OO style.
        my $uin        = ${$self}{data}{"./uin"}{value};
        my $properties =
          { year => ${$self}{data}{"./metadata/itemLevel/year"}{value} };
        $xml  = Koha::ILLRequest::Abstract->new()
          ->checkAvailability($uin, $properties);
    }

    # Check for valid API response.
    my $msg = $xml->findvalue('/apiResponse/message');
    my $sts = $xml->findvalue('/apiResponse/status');
    die "API Error: '$msg' (Error code: $sts).\n" if ($sts != '0');

    my $avail = [];
    # Build Availability Results
    foreach my $datum ($xml->findnodes('/apiResponse/result/availability')) {
        push @{$avail},
          $self->_parseResponse($datum, ${$self}{avail_props}, {});
    }

    return $avail;
}

=head3 checkPrices

    my $prices = $illRequest->checkPrices();

Use our API to return a generic structure on prices, formats, services and
delivery times and return it as a suitably formatted associative array.

=cut

sub checkPrices {
    my ( $self ) = @_;
    my $xml  = Koha::ILLRequest::Abstract->new()->getPrices();
    my $prices = [];

    # Check for valid API response.
    my $msg = $xml->findvalue('/apiResponse/message');
    my $sts = $xml->findvalue('/apiResponse/status');
    die "API Error: '$msg' (Error code: $sts).\n" if ($sts != '0');

    # Build Prices Results (there should only be one result node...)
    foreach my $datum ($xml->findnodes('/apiResponse/result')) {
        push @{$prices}, $self->_parseResponse($datum);
    }

    return $prices;
}

sub _parseResponse {
    my ( $self, $chunk, $config, $accum ) = @_;
    if ( $config eq "avail" ) {
        $config = ${$self}{avail_props};
    } elsif ( $config eq "price" ) {
        $config = ${$self}{price_props};
    }
    $accum = {} if ( !$accum );
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
            ${$accum}{$field} = [ ${$config}{$field}{name}, $chunk->$op($arg) ];
        }
    }
    return $accum;
}

=head3 create_from_xml

    $rec->create_from_xml($xml);

Populates a record object with data from a service xml reply: traverse xml,
storing each data point defined in config's properties' structure; build 
list of accessors -> data point mappings.

=cut

sub create_from_xml {
    my ( $self, $xml ) = @_;

    # for each property defined in the API config...
    foreach my $field ( keys ${$self}{record_props} ) {
        # populate data if desired.
        ${$self}{data}{$field} =
          {
           value      => $xml->findvalue($field),
           name       => ${$self}{record_props}{$field}{name},
           inSummary  => ${$self}{record_props}{$field}{inSummary},
          };
        # populate accessor if desired.
        my $accessor = ${$self}{record_props}{$field}{accessor};
        if ($accessor) {
            ${$self}{accessors}{$accessor} = ${$self}{data}{$field}{value};
        }
    }

    return $self;
}

=head3 create_from_store


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
    my %summary;
    foreach my $datum ( keys ${$self}{data} ) {
        my $summarize = ${$self}{data}{$datum}{inSummary};
        my $name = ${$self}{data}{$datum}{name};
        if ($summarize and $name) {
            $summary{$datum} = [ $name, ${$self}{data}{$datum}{value} ];
        }
    }
    return \%summary;
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
        $result = "Accessor '" . $accessor . "' not defined in config.";
    }
    return $result;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
