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
    my $test  = shift;
    my $self  = _load_config_file(C4::Context->config("illconfig"));
    bless $self, $class;

    ${$self}{configuration}{keywords} =
      [ "name", "accessor", "inSummary", "many" ];

    $self->{configuration}->{credentials} = _load_credentials(
        {
            api_keys         => C4::Context->config("ill_keys"),
            api_application  => C4::Context->config("ill_application_key"),
        }
    ) unless ( $test );

    ${$self}{record_props} = $self->_deriveProperties(${$self}{record});
    ${$self}{availability_props} =
      $self->_deriveProperties(${$self}{availability});
    ${$self}{prices_props} = $self->_deriveProperties(${$self}{prices});
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
                            kwrds => ${$self}{configuration}{keywords},
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

=head3 getCredentials

    my $credentials = $config->getCredentials($branchCode);

Fetch the best-fit credentials: if we have credentials for $branchCode, use
those; otherwise fall back on default credentials.  If neither can be found,
simply populate application details, and populate key details with 0.

=cut

sub getCredentials {
    my ( $self, $branchCode ) = @_;
    my $creds = $self->{configuration}->{credentials}
        || die "We have no credentials defined.  Please check koha-conf.xml.";

    my $exact = { api_key => 0, api_auth => 0 };
    if ( $branchCode && $creds->{api_keys}->{$branchCode} ) {
        $exact = $creds->{api_keys}->{$branchCode}
    } elsif ( $creds->{api_keys}->{default} ) {
        $exact = $creds->{api_keys}->{default};
    }

    return {
        api_key              => $exact->{api_key},
        api_key_auth         => $exact->{api_auth},
        api_application      => $creds->{api_application}->{key},
        api_application_auth => $creds->{api_application}->{auth},
    };
}

=head3 _load_credentials

    my $_load_credentials = $config->_load_credentials(
        { api_keys => $keys_hash, api_application => $app_hash }
    );

Read the configuration values passed as the parameter, and populate a hashref
suitable for use with these.

=cut

sub _load_credentials {
    my ( $params ) = @_;

    die "ILL_KEYS have not been defined in koha-conf.xml."
        unless ( ref($params->{api_keys}) eq "HASH" );

    die "ILL_APPLICATION_KEY has not been defined in koha-conf.xml."
        unless ( ref($params->{api_application}) eq "HASH" );

    my $credentials = {};

    # Per Branch Credentials
    my $branches = $params->{api_keys}->{branch};
    if ( ref($branches) eq "ARRAY" ) { # Multiple branches
        foreach my $branch ( @{$branches} ) {
            if ( $branch->{api_key} && $branch->{api_auth} ) {
                $credentials->{api_keys}->{$branch->{code}} = {
                    api_key  => $branch->{api_key},
                    api_auth => $branch->{api_auth},
                }
            }
        }
    } elsif ( ref($branches) eq "HASH" ) { # One branch only
        if ( $branches->{api_key} && $branches->{api_auth} ) {
            $credentials->{api_keys}->{$branches->{code}} = {
                api_key  => $branches->{api_key},
                api_auth => $branches->{api_auth},
            }
        }
    }

    # Default Credentials
    if ( $params->{api_keys}->{api_key} && $params->{api_keys}->{api_auth} ) {
        $credentials->{api_keys}->{default} = {
            api_key  => $params->{api_keys}->{api_key},
            api_auth => $params->{api_keys}->{api_auth},
        }
    }

    # Application key & auth
    $credentials->{api_application}  = {
        key  => $params->{api_application}->{key},
        auth => $params->{api_application}->{auth},
    };

    return $credentials;
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
