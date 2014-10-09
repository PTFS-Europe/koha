package C4::ILL::Config;

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
use YAML;

=head1 NAME

C4::ILL::Config - Koha ILL Configuration Object

=head1 SYNOPSIS

Object-oriented class that giving access to the illconfig data derived
from ill/config.yaml.

=head1 DESCRIPTION

This config object can be used for dynamic form generation, as a data
structure mapper between external data sourced by API calls or
alternatively as the source of data when composing API calls.

In particular the config object uses a YAML file, whose path is
defined by <illconfig> in koha-conf.xml. That YAML file provides the
data structure exposed in this object.

At present the data structure complies with fields used by the British
Library Interlibrary Loan DSS API.

=head1 API

=head2 Class Methods

=head3 new

    my $config = C4::ILL::Config->new();

Create a new C4::ILL::Config object, with mapping data loaded from the
ILL configuration file.

=cut

sub new {
    my $class = shift;
    my $self  = _load_config_file(C4::Context->config("illconfig"));

    bless $self, $class;
    return $self;
}

=head3 get_types

    $types = $config->get_types()

Return a reference to a hash mapping ILL map type ids to their human
friendly name, which can be used in, for instance HTML forms.

=cut

sub get_types {
    my $self = shift;
    my $types;
    for my $id ( keys ${$self}{request_types} ) {
        ${$types}{$id} = ${$self}{request_types}{$id}{name};
    }
    return $types;
}

=head3 get_type_details

    $type = $config->get_type_details($type_id)

Return a reference to a hash containing the full contents of the ILL
map type identified by the string $TYPE_ID.

The hash will contain at least a name -> human-friendly string and a
levels hash, which maps ids to names for defined fields at the given
levels.

This mapping is provided by the illconfig file.

If no type of id $TYPE_ID can be found, return undef.

=cut

sub get_type_details {
    my ($self, $type_id) = @_;
    return $self->_expand_fields($type_id);
}


=head3 _expand_fields

    $type = $self->_expand_fields($type_id)

This is an internal method that should not normally be used outside of
this file.

Return a reference to a type hash. The primary logic in this method is
to expand the fields, which are stored as mere field ids in the Config
object to their actual field contents, as defined by the respective
fields in illconfig.

Returns undef if $TYPE_ID does not identify a known ILL type.

=cut


sub _expand_fields {
    my ($self, $type_id) = @_;
    my $type = ${$self}{request_types}{$type_id};

    if ( $type ) {
        my $levels = ${$type}{levels};
        for my $level ( keys $levels ) {
            my $fields = ${$self}{$level};
            my $selected_fields = { };

            for my $id ( @{${$levels}{$level}} ) {
                ${$selected_fields}{$id} = ${$fields}{$id}
                  if ( ${$fields}{$id} );
            }

            ${$type}{levels}{$level} = $selected_fields;
        }
    }
    return $type;
}

sub _load_config_file {
    my ($config_file) = @_;
    die "The ill config file (" . $config_file . ") does not exist"
      if not -e $config_file;
    return YAML::LoadFile($config_file);
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
