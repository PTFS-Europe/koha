#!/usr/bin/perl 
#-----------------------------------
# Script Name: build_holds_queue.pl
# Description: builds a holds queue in the tmp_holdsqueue table
#-----------------------------------
# FIXME: add command-line options for verbosity and summary
# FIXME: expand perldoc, explain intended logic

use Modern::Perl;

use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

use C4::Context;
use C4::HoldsQueue qw(CreateQueue);
use C4::Log qw( cronlogaction );
use Koha::Script -cron;

=head1 NAME

build_holds_queue.pl - Build the holds queue based on RealTimeHoldsQueue sys pref

=head1 SYNOPSIS

build_holds_queue.pl [-f]

 Options:
   -h --help        Brief help message
   -m --man         Full documentation
   -f --force       Fully rebuilds the holds queue even if RealTimeHoldsQueue is enabled

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item b<--force>

allows this script to rebuild the entire holds queue even if the realtimeholdsqueue system preference is enabled.

=back

=head1 DESCRIPTION

This script rebuilds the entire holds queue if RealTimeHoldsQueue is disabled.

If RealTimeHoldsQueue is enabled, this script will only consider unallocated holds to add to the queue.
This is useful when a real-time-hold fails to allocate due to closed libraries.
This allows the script to catch holds that may have become active but failed to trigger a real time update.

=cut

my $help  = 0;
my $man   = 0;
my $force = 0;

my $command_line_options = join( " ", @ARGV );

GetOptions(
    'h|help'  => \$help,
    'm|man'   => \$man,
    'f|force' => \$force,
);
pod2usage(1)                              if $help;
pod2usage( -exitval => 0, -verbose => 2 ) if $man;

my $rthq = C4::Context->preference('RealTimeHoldsQueue');
my $unallocated = 0;

if ( $rthq && !$force ) {
    say "RealTimeHoldsQueue system preference is enabled, holds queue not rebuilt. Checking unallocated holds only.";
    say "Use --force to force building the holds queue.";
    $unallocated = 1;
}

cronlogaction( { info => $command_line_options } );

CreateQueue({ unallocated => $unallocated });

cronlogaction( { action => 'End', info => "COMPLETED" } );
