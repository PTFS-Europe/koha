package C4::ClassSortRoutine::Eso;

# Copyright (C) 2007 LibLime
# 
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use vars qw($VERSION);

# set the version for version checking
$VERSION = 3.00;

=head1 NAME 

C4::ClassSortRoutine::Eso - generic call number sorting key routine

=head1 SYNOPSIS

use C4::ClassSortRoutine;

my $cn_sort = GetClassSortKey('Eso', $cn_class, $cn_item);

=head1 FUNCTIONS

=head2 get_class_sort_key

  my $cn_sort = C4::ClassSortRoutine::Eso::Eso($cn_class, $cn_item);

Generates sorting key for LC call numbers.

=cut

sub get_class_sort_key {
    my ($cn_class, $cn_item) = @_;

    $cn_class = '' unless defined $cn_class;
    $cn_item  = '' unless defined $cn_item;
    my $key = uc "$cn_class $cn_item";
    $key =~ s/^\s+//;				# leading white space
    $key =~ s/\s+$//;				# trailing white space
#    $key =~ s/^[^\p{IsAlnum}\s.]//g;		# remove non-alphanum
    $key =~ s/^([A-Z]+)/$1 /;			# space after alpha
    $key =~ s/(\.[A-Z])/ $1/g;			# space before alpha
    # handle first digit group
#    $key =~ s/(\d+)/sprintf("%-05.5d", $1)/xe;	# all numbers 3 digits
    $key =~ s/(\d+)/sprintf("%-03.3d", $1)/ge;	# all numbers 3 digits
    $key =~ s/\s+/_/g;				# white space to _
    $key =~ s/\./_/g;				# dot to _
    $key =~ s/\///g;				# remove /
#    $key =~ s/__/_/g;				# de-dup _
#    $key =~ s/[^\p{IsAlnum}_]//g;		# leading white space

    return $key;

}

1;

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

