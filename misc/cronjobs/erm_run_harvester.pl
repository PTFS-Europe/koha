#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2022 PTFS Europe
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
use Getopt::Long qw( GetOptions );
use POSIX;

use Koha::Script;
use Koha::ERM::UsageDataProviders;

# Command line option values
my $get_help = 0;
my $dry_run  = 0;
my $debug    = 0;

my $options = GetOptions(
    'h|help'  => \$get_help,
    'dry-run' => \$dry_run,
    'debug'   => \$debug
);

if ($get_help) {
    get_help();
    exit 1;
}

# TODO: Run only harvesters from usage data providers that are active?
my $udproviders = Koha::ERM::UsageDataProviders->search();
unless ( scalar @{ $udproviders->as_list() } ) {
    die "No usage data providers found.";
}

while ( my $udprovider = $udproviders->next ) {
    debug_msg( "Harvesting for usage data provider " . $udprovider->erm_usage_data_provider_id );
    $udprovider->run();
}

sub debug_msg {
    my ($msg) = @_;

    if ( !$debug ) {
        return;
    }

    if ( ref $msg eq 'HASH' ) {
        use Data::Dumper;
        $msg = Dumper $msg;
    }
    print STDERR "$msg\n";
}

sub get_help {
    print <<"HELP";
$0: Run a harvesting for a ERM usage data provider

This script will run the harvesting for usage data providers

Parameters:
    --help or -h                         get help
    --dry-run                            only produce a run report, without actually doing anything permanent
    --debug                              print additional debugging info during run

HELP
}
