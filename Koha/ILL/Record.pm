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
from the API's $XML response.

=cut

sub new {
    my ($class, $config, $xml) = @_;
    my $self = {
                properties  => $config->record_properties(),
                xml         => $xml,
                data        => {},
                accessors   => {},
               };

    bless $self, $class;
    $self->_make();             # populate data, accessors.
    return $self;
}

=head3 _make

    $self->_make();

Internal helper: traverse xml, storing each data point defined in
config's properties' structure; build list of accessors -> data point
mappings.

=cut

sub _make {
    my $self = shift;
    # for each property defined in the API's config...
    foreach my $field ( keys ${$self}{properties} ) {
        # populate data if desired.
        my $xpath = './' . join("/",split(/_/, $field));
        ${$self}{data}{$field} =
          {
           value      => ${$self}{xml}->findvalue($xpath),
           name       => ${$self}{properties}{$field}{name},
           inSummary  => ${$self}{properties}{$field}{inSummary},
          };
        # populate accessor if desired.
        my $accessor = ${$self}{properties}{$field}{accessor};
        if ($accessor) {
            ${$self}{accessors}{$accessor} = ${$self}{data}{$field}{value};
        }
    }
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
