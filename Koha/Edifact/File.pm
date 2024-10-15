package Koha::Edifact::File;

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

use base qw(Koha::Object);

=encoding utf8

=head1 Name

Koha::Edifact::File - Koha::Object class for single EDIFACT file

=head2 Class methods

=head3 vendor

  my $vendor = $edifile->vendor;

Returns the I<Koha::Acquisition::Bookseller> associated with this EDIFACT file

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head3 basket

  my $basket = $edifile->basket;

Returns the I<Koha::Acquisition::Basket> associated with this EDIFACT file.

=cut

sub basket {
    my ($self) = @_;
    my $basket_rs = $self->_result->basketno;
    return unless $basket_rs;
    return Koha::Acquisition::Basket->_new_from_dbic($basket_rs);
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Edifact::File object
on the API.

=cut

sub to_api_mapping {
    return {
        message_type => 'type',
        basketno     => 'basket_id',
        deleted      => undef,
    };
}

=head2 Internal methods

=head3 _type

Returns name of corresponding DBIC resultset

=cut

sub _type {
    return 'EdifactMessage';
}

=head1 AUTHOR

Martin Renvoize <martin.renvoize@ptfs-europe.com>

Koha Development Team

=cut

1;
