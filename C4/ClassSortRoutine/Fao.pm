package C4::ClassSortRoutine::Fao;

# Copyright (C) 2010 PTFS-Europe Ltd
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

# set the version for version checking
our $VERSION = 3.01;

=head1 NAME

C4::ClassSortRoutine::Fao - fao call number sorting key routine

=head1 SYNOPSIS

use C4::ClassSortRoutine;

my $cn_sort = GetClassSortKey('Fao', $cn_class, $cn_item);

=head1 FUNCTIONS

=head2 get_class_sort_key

  my $cn_sort = C4::ClassSortRoutine::Fao::Fao($cn_class, $cn_item);

Generates sorting key using the following rules:

* Concatenates class and item part.
* Converts to upper-case

=cut

sub get_class_sort_key {
    my ( $cn_class, $cn_item ) = @_;

    $cn_class //= q{};
    $cn_item  //= q{};
    return uc "$cn_class $cn_item";

}

1;

=head1 AUTHOR

Colin Campbell <colin.campbell@ptfs-europe.com>

=cut
