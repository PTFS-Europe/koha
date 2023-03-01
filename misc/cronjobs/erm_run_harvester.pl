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
use Koha::ERM::Harvesters;

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

# TODO: Run only harvesters with a specific status? i.e. active
my $harvesters = Koha::ERM::Harvesters->search();
unless ( scalar @{ $harvesters->as_list() } ) {
    die "No SUSHI harvesters found.";
}

while ( my $harvester = $harvesters->next ) {
    debug_msg( "Running harvester " . $harvester->erm_harvester_id );
    $harvester->run();
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
$0: Run a ERM usage statistics harvester

This script will run the usage statistics harvesters

Parameters:
    --help or -h                         get help
    --dry-run                            only produce a run report, without actually doing anything permanent
    --debug                              print additional debugging info during run

HELP
}
