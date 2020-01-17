package Koha::Item::Transfer;

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
use Koha::DateUtils;

use base qw(Koha::Object);

=head1 NAME

Koha::Item::Transfer - Koha Item Transfer Object class

=head1 API

=head2 Class Methods

=cut

=head3 item

  my $item = Koha::Library->item;

Returns the associated item for this transfer.

=cut

sub item {
    my ( $self ) = @_;
    my $rs = $self->_result->itemnumber;
    return Koha::Item->_new_from_dbic( $rs );
}

=head3 transit

Set the transfer as in transit by updateing the datesent time.

=cut

sub transit {
    my ($self, $date) = @_;

    $date //= dt_from_string;
    $self->set({datesent => $date})->store;
    return $self;
}

=head3 type

=cut

sub _type {
    return 'Branchtransfer';
}

1;
