package Koha::Borrower::ILLRequests;

# Copyright PTFS Europe 2014
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

use Carp;

use Koha::Database;

use Koha::Borrower::ILLRequest;

use base qw(Koha::Objects);

=head1 NAME

Koha::Borrower::ILLRequests - Koha ILLRequests Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'IllRequest';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Borrower::ILLRequest';
}

=head1 AUTHOR

Martin Renvoize <martin.renovize@ptfs-europe.com>

=cut

1;
