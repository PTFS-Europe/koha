package Koha::ILL::Record;

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

Koha::ILL::Record - Koha ILL Record Object

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

    my $record = Koha::ILL::Record->new($config, $xml);

Create a new Koha::ILL::Record object, with mapping data loaded from
the ILL configuration file loaded as $CONFIG, and data content derived
from $XML.

=cut

# Constructor.
sub new {
    my ($class, $config, $xml) = @_;
    my $self = {
                properties  => $config->record_properties(),
                method_maps => $config->method_maps(),
                xml         => $xml,
               };

    bless $self, $class;
    $self->_make();             # transform XML to data structure.
    return $self;
}

# Traverse xml, storing each data point defined in config's
# properties' structure.
sub _make {
    my $self = shift;
    foreach my $field ( keys ${$self}{properties} ) {
        ${$self}{data}{$field}
          = ${$self}{xml}->findvalue('./' . join("/",split(/_/, $field)));
    }
}

# Helper to retrieve externally configured xml values.
sub _getterMaker {
    my ($self, $id) = @_;
    my $path = join("_", @{${$self}{method_maps}{$id}});
    my $result;
    if (defined ${$self}{data}{$path}) {
        $result = ${$self}{data}{$path};
    } else {
        $result = "Path defined by " . $id . " in config unknown.";
    }
    return $result;
}

# Accessors / Getters
sub getTitle {
    my $self = shift;
    return $self->_getterMaker('getTitle');
}

sub getAuthor {
    my $self = shift;
    return $self->_getterMaker('getAuthor');
}

sub getType {
    my $self = shift;
    return $self->_getterMaker('getType');
}

sub getIdentifier {
    my $self = shift;
    return $self->_getterMaker('getIdentifier');
}

sub getID {
    my $self = shift;
    return $self->_getterMaker('getID');
}

# meta-getter. $allowed defines the procedures which are allowed to be
# specified in the config file.
sub getSummary {
    my $self = shift;
    my @subs = @{${$self}{method_maps}{getSummary}};
    my $allowed = {
                   getID         => 1,
                   getTitle      => 1,
                   getAuthor     => 1,
                   getType       => 1,
                   getIdentifier => 1,
                  };
    my @results;
    foreach my $sub ( @subs ) {
        push(@results, $self->$sub())
          if (exists ${$allowed}{$sub});
    }
    return @results;
}

1;
