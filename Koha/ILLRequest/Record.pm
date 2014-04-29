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
                manual_props  => $config->getProperties('manual'),
                primary_props => {
                    primary_access_url => {
                        name      => "Access URL",
                        inSummary => undef,
                    },
                    primary_cost => {
                        name      => "Cost",
                        inSummary => "true",
                    },
                    primary_manual => {
                        name      => "Manually Created",
                        inSummary => "true",
                    },
                    primary_notes_opac => {
                        name      => "Opac notes",
                        inSummary => undef,
                    },
                    primary_notes_staff => {
                        name      => "Staff notes",
                        inSummary => undef,
                    },
                    primary_order_id   => {
                        name      => "Order ID",
                        inSummary => undef,
                    },
                },
                data          => {},
                accessors     => {},
               };
    bless $self, $class;

    # Primary fields are hardcoded: their accessors are too.
    $self->{primary_accessors} = {
        access_url  => $self->_make_xsor('primary_access_url'),
        cost        => $self->_make_xsor('primary_cost'),
        manual      => $self->_make_xsor('primary_manual'),
        notes_opac  => $self->_make_xsor('primary_notes_opac'),
        notes_staff => $self->_make_xsor('primary_notes_staff'),
        order_id    => $self->_make_xsor('primary_order_id'),
    };

    # Manual Entry is API provided.
    $self->{manual_entry_accessor} = sub {
        my $name = shift;
        return $self->_make_xsor($name);
    };

    return $self;
}

=head3 _make_xsor

    my $xsor = $record->_make_xsor('name');

Helper to generate primary accessor subs.  Return a sub which can get/set
primary accessor values of type 'name'.

=cut

sub _make_xsor {
    my ( $self, $name ) = @_;
    return sub {
        my ( $value, $display, $inSummary ) = @_;
        $self->{data}->{$name}->{value}     = $value     if ( $value );
        $self->{data}->{$name}->{name}      = $display   if ( $display );
        $self->{data}->{$name}->{inSummary} = $inSummary if ( $inSummary );
        return $self->{data}->{$name}->{value};
    }
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
        if ( ref $config->{$field} eq 'ARRAY' ) {
            foreach my $node ($chunk->findnodes($field)) {
                $accum->{$field} = [] if ( !$accum->{$field} );
                push @{$accum}{$field},
                  $self->_parseResponse($node, ${$config}{$field}[0], {});
            }
        } else {
            my ( $op, $arg ) = ( "findvalue", $field );
            ( $op, $arg ) = ( "textContent", "" )
              if ( $field eq "./" );
            $accum->{$field} = {
                value     => $chunk->$op($arg),
                name      => $config->{$field}->{name},
                inSummary => $config->{$field}->{inSummary},
            };
            # FIXME: populate accessor if desired.  This breaks the
            # functional-ish approach by referencing $self directly.
            my $accessor = $config->{$field}->{accessor};
            if ($accessor) {
                $self->{accessors}->{$accessor} = sub {
                    return $accum->{$field}->{value};
                };
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

=head3 create_from_manual_entry

    my $record = $record->create_from_manual_entry($values);

Populate $record with $VALUES, the result of manual_entry rather than API or
store operations.

=cut

sub create_from_manual_entry {
    my ( $self, $values ) = @_;
    while ( my ( $id, $properties ) = each $self->{manual_props} ) {
        $self->manual_property(
            $id, $values->{$id}, $properties->{name}, $properties->{inSummary}
        );
    }
    $self->property('manual', "True");
    return $self;
}

=head3 create_from_store

    my $create_from_store = $illRequest->create_from_store($attributes);

Parse $ATTRIBUTES, which should be the result of querying the database for
this Record's intended contents.

=cut

sub create_from_store {
    my ( $self, $attributes ) = @_;

    # Populate manual entry fields
    while ( my ($id, $props) = each %{$self->{manual_props}} ) {
        $self->manual_property(
            $id, $attributes->{$id}, $props->{name}, $props->{inSummary}
        )
    }

    # Populate dynamic API fields
    foreach my $field ( keys $self->{record_props} ) {

        # populate data from database
        $self->{data}->{$field} = {
            value     => $attributes->{$field},
            name      => $self->{record_props}->{$field}->{name},
            inSummary => $self->{record_props}->{$field}->{inSummary},
        };

        # populate accessor if desired
        my $accessor = $self->{record_props}->{$field}->{accessor};
        if ( $accessor ) {
            $self->{accessors}->{$accessor} = sub {
                return $self->{data}->{$field}->{value};
            };
        }
    }

    # Populate 'primary values'
    foreach my $field ( keys $self->{primary_props} ) {
        $self->{data}->{$field} = {
            value     => $attributes->{$field},
            name      => $self->{primary_props}->{$field}->{name},
            inSummary => $self->{primary_props}->{$field}->{inSummary},
        };
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
    my ( $self, $data) = @_;
    my $merged = $self->_merge_manual($data);
    my $summary = {};
    while ( my ( $id, $props ) = each %{$merged} ) {
        if ( $props->{name} and $props->{inSummary} ) {
            $summary->{$id} = [ $props->{name}, $props->{value} ];
        }
    }
    return $summary;
}

=head3 _merge_manual

    my $_merge_manual = $illRequest->_merge_manual();

For some displays we desperately want to avoid passing back both API fields
and manual fields.  Furthermore, we need to reduce the Manual fields to the
API fieldset, so we can display Manual values in tables compatible with API
created ILLs.

=cut

sub _merge_manual {
    my ( $self, $data ) = @_;
    my $manual = $self->property('manual');
    while ( my ( $id, $props ) = each %{$self->{record_props}} ) {
        $data->{$id}->{value} = $data->{'m' . $id}->{value}
            if ( $manual );
        delete $data->{'m' . $id};
    }
    return $data;
}

=head3 getFullDetails

    $rec->getFullDetails();

Return a hashref mapping config human names for fields to their
values, if the fields have been defined by the yaml config.

=cut

sub getFullDetails {
    my ( $self, $params ) = @_;
    my $details = {};
    while ( my ( $key, $value ) = each $self->{data} ) {
        if ( $value->{name} ) {
            $details->{$key} = [ $value->{name}, $value->{value} ]
                unless ( 'primary_notes_staff' eq $key
                         and $params->{censor_notes_staff} );
        }
    }
    return $details;
}

=head3 update

    my $updated_record = $record->update( $new_primary_values );

Cycle through all primary accessors, and update values as needed.  The
non-primary values in record should be read only, hence are not touched here.

We will return an arrayref containing the updated names of updated primary
accessors.

=cut

sub update {
    my ( $self, $new_values ) = @_;
    my @updated;
    while ( my ( $name, $proc ) = each %{$self->{primary_accessors}} ) {
        my $pname = 'primary_' . $name;
        my $new   = $new_values->{$pname};
        if ( $new ) {
            &{$proc}($new) unless ( '' eq $new );
            push @updated, $name;
        }
    }
    return \@updated;
}

=head3 introspect_primary_properties

    my $introspect_primary_properties = $illRequest->introspect_primary_properties();

Return a list of defined primary property keys.

=cut

sub introspect_primary_properties {
    my ( $self ) = @_;
    return keys %{$self->{primary_props}};
}

=head3 manual_property

    my $newPropertyValue || 0 = $record->manual_property(
        'propertyID', 'newPropertyValue', 'propertyName', 'inSummary'
    );

Means of accessing and setting properties according to Record's API.

=cut

sub manual_property {
    my ( $self, $id, $value, $name, $inSummary ) = @_;
    my $result = 0;
    if ( $self->{manual_props}->{$id} ) {
        # magic command to 'unset' field value.
        $value = "" if ( 'UNSET' eq $value );
        my $accessor = &{$self->{manual_entry_accessor}}($id);
        return &{$accessor}($value, $name, $inSummary);
    }
}

=head3 property

    my $newPropertyValue || 0 = $record->property(
        'propertyName', 'newPropertyValue'
    );

Means of accessing and setting properties according to Record's API.  This is
primarily used for setting primary_ accessor values.

=cut

sub property {
    my ( $self, $prop_name, $prop_value ) = @_;
    my $result = 0;
    if ( $prop_value ) {        # 'set' operation
        if ( defined $self->{primary_accessors}->{$prop_name} ) {
            my $value = $prop_value;
            $result = $prop_value;
            if ( 'UNSET' eq $prop_value ) {
                $value = "";
                $result = 1;
            }
            $self->{data}->{'primary_' . $prop_name} =
                $self->{primary_props}->{'primary_' . $prop_name};
            $self->{data}->{'primary_' . $prop_name}->{value} = $value;
        }
    } else {                    # 'get' operation
        $result = $self->getProperty($prop_name);
    }
    return $result;
}


=head3 getProperty

    $rec->getPoperty(ID);

Return the value of the field identified by the `accessor id' ID,
defined in config.yaml.  If ID does not map to a field, return a
warning message.

=cut

sub getProperty {
    my ($self, $accessor) = @_;
    my $result = 0;
    for ( qw/ primary_accessors accessors / ) {
        my $xsor = $self->{$_}->{$accessor};
        $result = &{$xsor}() if ( 'CODE' eq ref $xsor );
    }
    return $result;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
