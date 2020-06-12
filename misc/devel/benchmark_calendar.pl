#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2016 Koha Development Team
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
use Benchmark;

use DateTime;
use DateTime::Set;
use DateTime::Event::Random;

my $start = DateTime->new( year => 2020, month => 3 );
my $end   = DateTime->new( year => 2020, month => 5 );
my $set   = DateTime::Event::Random->new_cached(
    days  => 5,
    start => $start,
    end   => $end
);

my $exception_holidays = {};
my $iter               = $set->iterator;
while ( my $dt = $iter->next ) {
    $exception_holidays->{ $dt->ymd('') } = 1;
}

my $test_datetime =
  DateTime::Event::Random->datetime( start => $start, end => $end );
my $test_datestring = $test_datetime->ymd('');

my $time_set = sub {
    return $set->contains($test_datetime);

};

my $time_hash = sub {
    return 1 if ( $exception_holidays->{$test_datestring} );
    return 0;

};

Benchmark::cmpthese(
    -10,
    {
        'DateTime::Set' => $time_set,
        'hashref'       => $time_hash,
    }
);
