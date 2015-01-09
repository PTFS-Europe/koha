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
use Clone qw( clone );
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

    ${$self}{semantics}{keywords} =
      [ "name", "accessor", "inSummary", "many" ];

    ${$self}{record_props} = $self->_deriveProperties(${$self}{record});
    ${$self}{availability_props} =
      $self->_deriveProperties(${$self}{availability});
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
    my ($self, $source) = @_;
    my $modifiedSource = clone($source);
    delete ${$modifiedSource}{many};
    return $self->_recurse(
                           {
                            accum => {},
                            tmpl  => $modifiedSource,
                            kwrds => ${$self}{semantics}{keywords},
                           },
                          );
}

sub _recurse {
    my ($self, $args, @prefix) = @_;
    # We manufacture an accumulated result set indexed by xpaths.
    my $xpath = "./" . join("/", @prefix);

    if ( ${$args}{tmpl}{many} and ${$args}{tmpl}{many} eq "yes" ) {
        # The many keyword is special: it means we create a new root.
        ${$args}{accum}{$xpath} =
          [ $self->_deriveProperties(${$args}{tmpl}) ];
    } else {
        while ( my ($key, $value) = each ${$args}{tmpl} ) {
            if ( $key ~~ ${$args}{kwrds} ) {
                # syntactic keyword entry -> add keyword entry's value to the
                # current prefix entry in our accumulated results.
                if ( $key eq "inSummary" ) {
                    # inSummary should only appear if it's "yes"...
                    ${$args}{accum}{$xpath}{$key} = 1 if $value eq "yes";
                } else {
                    # otherwise simply enrich.
                    ${$args}{accum}{$xpath}{$key} = $value;
                }
            } else {
                # non-keyword & non-root entry -> simple recursion to add it
                # to our accumulated results.
                $self->_recurse(
                                {
                                 accum => ${$args}{accum},
                                 tmpl  => ${$args}{tmpl}{$key},
                                 kwrds => ${$args}{kwrds},
                                },
                                @prefix,
                                $key
                               );
            }
        }
    }
    return ${$args}{accum};
}

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
