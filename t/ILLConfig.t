#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('C4::ILL::Config');
}

my $class = 'C4::ILL::Config';

my $obj = $class->new();

isa_ok( $obj, $class );
