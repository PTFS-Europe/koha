#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More;
use Test::Warn;

use Koha::ILLRequest::Record;

use Data::Dump qw( dump);

# Some data structures that will be repeatedly referenced
my $defaults  = {
    api_key  => "564euie",
    api_auth => "unidaenudvnled",
};
my $application = {
    key  => "6546uedrun",
    auth => "edutrineadue",
};
# Simulate $from_xml
my $params = {
    configuration  => $defaults,
    application    => $application,
};
my $first_branch = {
    code => "test", api_key => "dphügnpgüffq", api_auth => "udrend"
};
my $second_branch = {
    code          => "second",
    api_key       => "eduirn",
    api_auth      => "eudtireand",
    request_limit => "5",
};

BEGIN {
    use_ok('Koha::ILLRequest::Config');
}

my $config = Koha::ILLRequest::Config->new(1); # with test_mode enabled.
isa_ok($config, 'Koha::ILLRequest::Config');

# _load_configuration
is_deeply(
    Koha::ILLRequest::Config::_load_configuration($params),
    {
        credentials => {
            api_keys        => { default => $defaults },
            api_application => $application,
        },
        limits      => {},
    },
    "Basic _load_configuration"
);

$params->{configuration}->{request_limit} = 10;
is_deeply(
    Koha::ILLRequest::Config::_load_configuration($params),
    {
        credentials => {
            api_keys        => {
                default => {
                    api_key  => $defaults->{api_key},
                    api_auth => $defaults->{api_auth}
                }
            },
            api_application => $application,
        },
        limits          => { default => 10 },
    },
    "Basic _load_configuration, with limit"
);

$params->{configuration}->{branch} = $first_branch;
is_deeply(
    Koha::ILLRequest::Config::_load_configuration($params),
    {
        credentials => {
            api_keys        => {
                default => {
                    api_key  => $defaults->{api_key},
                    api_auth => $defaults->{api_auth},
                },
                $first_branch->{code} => {
                    api_key  => $first_branch->{api_key},
                    api_auth => $first_branch->{api_auth},
                },
            },
            api_application => $application,
        },
        limits          => { default => 10 },
    },
    "Single Branch _load_configuration"
);

$params->{configuration}->{branch} = [ $first_branch, $second_branch ];
is_deeply(
    Koha::ILLRequest::Config::_load_configuration($params),
    {
        credentials => {
            api_keys        => {
                default => {
                    api_key  => $defaults->{api_key},
                    api_auth => $defaults->{api_auth},
                },
                $first_branch->{code} => {
                    api_key  => $first_branch->{api_key},
                    api_auth => $first_branch->{api_auth},
                },
                $second_branch->{code} => {
                    api_key  => $second_branch->{api_key},
                    api_auth => $second_branch->{api_auth},
                },
            },
            api_application => $application,
        },
        limits          => { default => 10, $second_branch->{code} => 5}
    },
    "Multi Branch _load_configuration"
);

# getCredentials
$params = {
    configuration => {},
    application   => $application,
};
$config->{configuration} =
    Koha::ILLRequest::Config::_load_configuration($params);
is_deeply(
    $config->getCredentials,
    {
        api_key              => 0,
        api_key_auth         => 0,
        api_application      => $application->{key},
        api_application_auth => $application->{auth},
    },
    "getCredentials, no creds, just App."
);

$params->{configuration} = $defaults;
$config->{configuration} =
    Koha::ILLRequest::Config::_load_configuration($params),
is_deeply(
    $config->getCredentials,
    {
        api_key              => $defaults->{api_key},
        api_key_auth         => $defaults->{api_auth},
        api_application      => $application->{key},
        api_application_auth => $application->{auth},
    },
    "getCredentials, default creds & App."
);

$params->{configuration}->{branch} = $first_branch;
$config->{configuration} =
    Koha::ILLRequest::Config::_load_configuration($params),
is_deeply(
    $config->getCredentials($first_branch->{code}),
    {
        api_key              => $first_branch->{api_key},
        api_key_auth         => $first_branch->{api_auth},
        api_application      => $application->{key},
        api_application_auth => $application->{auth},
    },
    "getCredentials, $first_branch->{code} creds & App."
);

is_deeply(
    $config->getCredentials("random"),
    {
        api_key              => $defaults->{api_key},
        api_key_auth         => $defaults->{api_auth},
        api_application      => $application->{key},
        api_application_auth => $application->{auth},
    },
    "getCredentials, fallback creds & app."
);

done_testing;
