package Koha::ILLRequest::Config;

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

Koha::ILLRequest::Config - Koha ILL Configuration Object

=head1 SYNOPSIS

Object-oriented class that giving access to the illconfig data derived
from ill/config.yaml.

=head1 DESCRIPTION

Config object providing abstract representation of the expected XML
returned by ILL API.

In particular the config object uses a YAML file, whose path is
defined by <illconfig> in koha-conf.xml. That YAML file provides the
data structure exposed in this object.

By default the configured data structure complies with fields used by
the British Library Interlibrary Loan DSS API.

The config file also provides mappings for Record Object accessors.

=head1 API

=head2 Class Methods

=head3 new

    my $config = Koha::ILLRequest::Config->new();

Create a new Koha::ILLRequest::Config object, with mapping data loaded from the
ILL configuration file.

=cut

sub new {
    my $class = shift;
    my $self  = _load_config_file(C4::Context->config("illconfig"));
    bless $self, $class;
    $self->_derive_record_properties();
    return $self;
}

# Obsolete?
sub get_types {
    return { no_longer_used => "Ignore" };
}

=head3 _derive_record_properties

    $self->_derive_record_properties();

Translate config file data structure into ILL module friendly hashref,
without losing data required to traverse XML response.

=cut

sub _derive_record_properties {
    my ($self) = @_;
    return $self->_next_level(${$self}{record});
}

=head3 _next_level

    $self->_next_level(TODO, PREFIX);

Provide means for _derive_record_properties to recursively process the
config data structure.  TODO is the next level of the recursive
structure; PREFIX the next part of the name to prepend for the key in
the final hash.

=cut

sub _next_level {
    my ($self, $todo, @prefix) = @_;
    foreach my $id ( keys $todo ) {
        if ( $id eq 'go') {
        } elsif ( ${$todo}{$id}{go} ) {
            $self->_next_level(${$todo}{$id}, @prefix , $id);
        } else {
            ${$self}{record_properties}{join("_", @prefix , $id)}
              = ${$todo}{$id};
        }
    }
    return ${$self}{record_properties};
}
# End translation.

=head3 record_properties

    $properties = $config->record_properties();

Return the record_properties, a data structure derived from parsing
the ILL yaml config.

=cut

sub record_properties {
    my $self = shift;
    return ${$self}{record_properties};
}

=head3 _load_config_file

    _load_config_file(FILENAME);

Return a hashref, the result of loading FILENAME using the YAML
loader, or raise an error.

=cut

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
