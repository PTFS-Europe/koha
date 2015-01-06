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
    $self->_deriveProperties("record_props", ${$self}{record});
    $self->_deriveProperties("availability_props", ${$self}{availability});
    return $self;
}

# Obsolete?
sub get_types {
    return { no_longer_used => "Ignore" };
}

=head3 _deriveProperties

    my $_derivedProperties = $illRequest->_deriveProperties($target, $source);

Translate config file's $TARGET data structure into an ILL module friendly
hashref, without losing data required for traversal of XML responses.

The hashref will be stored in $SOURCE.

=cut

sub _deriveProperties {
    my ($self, $target, $source) = @_;
    return $self->_nextLevel($target, $source);
}

=head3 _nextLevel

    $self->_nextLevel($target, $todo, $prefix);

Provide means for _deriveProperties to recursively process the config data
structure.  $TARGET is the key under which the resulting data structure will
be saved in $self.  $TODO is the next level of the recursive structure;
$PREFIX the next part of the name to prepend for the key in the final hash.

=cut

sub _nextLevel {
    my ($self, $target, $todo, @prefix) = @_;
    foreach my $id ( keys $todo ) {
        if ( $id eq 'go') {
        } elsif ( ${$todo}{$id}{go} ) {
            $self->_nextLevel($target, ${$todo}{$id}, @prefix , $id);
        } else {
            ${$self}{$target}{join("_", @prefix , $id)} = ${$todo}{$id};
        }
    }
    return ${$self}{$target};
}
# End translation.

=head3 getProperties

    $properties = $config->getProperties($name);

Return the properties of type $NAME, a data structure derived from parsing the
ILL yaml config.

At present we provide "record" and "availability" properties.

=cut

sub getProperties {
    my ( $self, $name ) = @_;
    return ${$self}{$name . "_props"};
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
