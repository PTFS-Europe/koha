package Koha::Item::Bundle;

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

use Koha::Database;

use base qw(Koha::Item);

=head1 NAME

Koha::Item::Bundle - Koha Item Bundle Object class

=head1 API

=head2 Class Methods

=head3 host

  my $host = $bundle->host;

Returns the associated host item for this bundle.

=cut

sub host {
    my ($self) = @_;
    my $host_rs = $self->_result->itemnumber;
    return Koha::Item->_new_from_dbic($host_rs);
}

=head3 items

  my $items = $bundle->items;

Returns the associated items attached to this bundle.

=cut

sub items {
    my ($self) = @_;
    my $items_rs = $self->_result->itemnumbers;
    return Koha::Items->_new_from_dbic($items_rs);
}

=head3 type

=cut

sub _type {
    return 'Item';
}

1;
