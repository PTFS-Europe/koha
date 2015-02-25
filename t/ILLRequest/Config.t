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

BEGIN {
    use_ok('Koha::ILLRequest::Config');
}

my $config = Koha::ILLRequest::Config->new;
isa_ok($config, 'Koha::ILLRequest::Config');

# _load_credentials
my $default_key = "564euie";
my $application_key = "6546uedrun";
my $params = {
    api_keys        => { api_key => $default_key },
    api_application => $application_key,
};

is_deeply(
    $config->_load_credentials($params),
    {
        api_keys        => { default => $default_key },
        api_application => $application_key
    },
    "Basic _load_credentials"
);

my $first_branch = { code => "test", api_key => "dphügnpgüffq" };
$params->{api_keys}->{branch} = $first_branch;
is_deeply(
    $config->_load_credentials($params),
    {
        api_keys        => {
            default               => $default_key,
            $first_branch->{code} => $first_branch->{api_key},
        },
        api_application => $application_key
    },
    "Single Branch _load_credentials"
);

my $second_branch = { code => "second", api_key => "eduirn"};
$params->{api_keys}->{branch} = [ $first_branch, $second_branch ];
is_deeply(
    $config->_load_credentials($params),
    {
        api_keys        => {
            default                => $default_key,
            $first_branch->{code}  => $first_branch->{api_key},
            $second_branch->{code} => $second_branch->{api_key},
        },
        api_application => $application_key
    },
    "Multi Branch _load_credentials"
);

# getCredentials
$config->{configuration}->{credentials} = $config->_load_credentials($params);
is_deeply(
    $config->getCredentials($second_branch->{code}),
    {
        api_key         => $second_branch->{api_key},
        api_application => $application_key,
    },
    "getCredentials match"
);

is_deeply(
    $config->getCredentials("nonsense"),
    {
        api_key         => $default_key,
        api_application => $application_key,
    },
    "getCredentials fall-back match"
);

done_testing;
