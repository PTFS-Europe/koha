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
use C4::Context;
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
    my $self  = {};

    $self->{configuration} = _load_configuration(
        C4::Context->config("interlibrary_loans"),
        C4::Context->preference("UnmediatedILL")
      ) unless ( $test );

    $self->{configuration}->{keywords} =
      [ "name", "accessor", "inSummary", "many" ];

    bless $self, $class;

    my $spec  = _load_api_specification(
        C4::Context->config("interlibrary_loans")->{api_specification}
      );
    $self->{record_props} = $self->_deriveProperties($spec->{record});
    $self->{availability_props} =
      $self->_deriveProperties($spec->{availability});
    $self->{prices_props} = $self->_deriveProperties($spec->{prices});
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

=head3 getPrefixes

    my $prefixes = $config->getPrefixes('brw_cat' | 'branch');

Return the prefix for ILLs defined by our config.

=cut

sub getPrefixes {
    my ( $self, $type ) = @_;
    die "Unexpected type." unless ( $type eq 'brw_cat' || $type eq 'branch' );
    my $values = $self->{configuration}->{prefixes}->{$type};
    $values->{default} = $self->{configuration}->{prefixes}->{default};
    return $values;
}

=head3 getLimitRules

    my $rules = $config->getLimitRules('brw_cat' | 'branch')

Return the hash of ILL limit rules defined by our config.

=cut

sub getLimitRules {
    my ( $self, $type ) = @_;
    die "Unexpected type." unless ( $type eq 'brw_cat' || $type eq 'branch' );
    my $values = $self->{configuration}->{limits}->{$type};
    $values->{default} = $self->{configuration}->{limits}->{default};
    return $values;
}


=head3 getDefaultFormats

    my $defaultFormat = $config->getLimitRules('brw_cat' | 'branch')

Return the hash of ILL default formats defined by our config.

=cut

sub getDefaultFormats {
    my ( $self, $type ) = @_;
    die "Unexpected type." unless ( $type eq 'brw_cat' || $type eq 'branch' );
    my $values = $self->{configuration}->{default_formats}->{$type};
    $values->{default} = $self->{configuration}->{default_formats}->{default};
    return $values;
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

=head3 getApiUrl

    my $api_url = $config->getApiUrl;

Return the url for the api configured by koha-conf.xml, or the fall-back url.

=cut

sub getApiUrl {
    my ( $self ) = @_;
    return $self->{configuration}->{api_url};
}

=head3 _load_configuration

    my $configuration = $config->_load_configuration($config_from_xml);

Read the configuration values passed as the parameter, and populate a hashref
suitable for use with these.

=cut

sub _load_configuration {
    my ( $from_xml, $unmediated ) = @_;
    my $xml_config  = $from_xml->{configuration};
    my $xml_api_url = $from_xml->{api_url};

    # Input validation
    die "CONFIGURATION has not been defined in koha-conf.xml."
        unless ( ref($xml_config) eq "HASH" );
    die "APPLICATION has not been defined in koha-conf.xml."
        unless ( ref($from_xml->{application}) eq "HASH" );

    # Default data structure to be returned
    my $configuration = {
        api_url         => $xml_api_url || 'http://apitest.bldss.bl.uk',
        credentials     => {
            api_application => {},
            api_keys        => {},
        },
        limits          => {},
        default_formats => {},
        prefixes        => {},
    };

    # Per Branch Configuration
    my $branches = $xml_config->{branch};
    if ( ref($branches) eq "ARRAY" ) {
        # Multiple branch overrides defined
        map { _load_unit_config($_, $_->{code}, $configuration, 'branch') }
            @{$branches};
    } elsif ( ref($branches) eq "HASH" ) {
        # Single branch override defined
        _load_unit_config(
            $branches, $branches->{code}, $configuration, 'branch'
        );
    }

    # Per Borrower Category Configuration
    my $brw_cats = $xml_config->{borrower_category};
    if ( ref($brw_cats) eq "ARRAY" ) {
        # Multiple branch overrides defined
        map { _load_unit_config($_, $_->{code}, $configuration, 'brw_cat') }
            @{$brw_cats};
    } elsif ( ref($brw_cats) eq "HASH" ) {
        # Single branch override defined
        _load_unit_config(
            $brw_cats, $brw_cats->{code}, $configuration, 'brw_cat'
        );
    }

    # Default Configuration
    _load_unit_config($xml_config, 'default', $configuration);

    # Application key & auth
    $configuration->{credentials}->{api_application}  = {
        key  => $from_xml->{application}->{key},
        auth => $from_xml->{application}->{auth},
    };

    die "No DEFAULT_FORMATS has been defined in koha-conf.xml, but UNMEDIATEDILL is active."
        if ( $unmediated && !$configuration->{default_formats}->{default} );

    return $configuration;
}

sub _load_unit_config {
    my ( $unit, $id, $config, $type ) = @_;
    return $config unless $id;

    if ( $unit->{api_key} && $unit->{api_auth} ) {
        $config->{credentials}->{api_keys}->{$id} = {
            api_key  => $unit->{api_key},
            api_auth => $unit->{api_auth},
        };
    }
    # Add request_limit rules.
    # METHOD := 'annual' || 'active'
    # COUNT  := x >= -1
    if ( ref $unit->{request_limit} eq 'HASH' ) {
        my $method  = $unit->{request_limit}->{method};
        my $count = $unit->{request_limit}->{count};
        if ( 'default' eq $id ) {
            $config->{limits}->{$id}->{method}  = $method
                if ( $method && ( 'annual' eq $method || 'active' eq $method ) );
            $config->{limits}->{$id}->{count} = $count
                if ( $count && ( -1 <= $count ) );
        } else {
            $config->{limits}->{$type}->{$id}->{method}  = $method
                if ( $method && ( 'annual' eq $method || 'active' eq $method ) );
            $config->{limits}->{$type}->{$id}->{count} = $count
                if ( $count && ( -1 <= $count ) );
        }
    }

    # Add prefix rules.
    # PREFIX := string
    if ( $unit->{prefix} ) {
        if ( 'default' eq $id ) {
            $config->{prefixes}->{$id} = $unit->{prefix};
        } else {
            $config->{prefixes}->{$type}->{$id} = $unit->{prefix};
        }
    }

    # Add default_formats types.
    # FORMAT && QUALITY && QUANTITY && SERVICE && SPEED := x >= 0
    if ( ref $unit->{default_formats} eq 'HASH' ) {
        my @fields = qw(format quality quantity service speed);
        if ( 'default' eq $id ) {
            for ( @fields ) {
                my $val = $unit->{default_formats}->{$_};
                die "Invalid default_formats: '$_' missing"
                    unless $val;
                $config->{default_formats}->{$id}->{$_} = $val;
            }
        } else {
            for ( @fields ) {
                my $val = $unit->{default_formats}->{$_};
                die "Invalid default_formats: '$_' missing"
                    unless $val;
                $config->{default_formats}->{$type}->{$id}->{$_} = $val;
            }
        }
    }

    return $config;
}

=head3 _load_api_specification

    _load_api_specification(FILENAME);

Return a hashref, the result of loading FILENAME using the YAML
loader, or raise an error.

=cut

sub _load_api_specification {
    my ($config_file) = @_;
    die "The ill config file (" . $config_file . ") does not exist"
      if not -e $config_file;
    return YAML::LoadFile($config_file);
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
