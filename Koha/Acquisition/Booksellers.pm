package Koha::Acquisition::Booksellers;

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

use Koha::Acquisition::Bookseller;

use base qw( Koha::Objects Koha::Object::Mixin::AdditionalFields Koha::Objects::Limit::LibraryGroup );

=head1 NAME

Koha::Acquisition::Booksellers object set class

=head1 API

=head2 Class methods

=head3 search

=cut

sub search {
    my ( $self, $params, $attributes ) = @_;

    my $class = ref($self) ? ref($self) : $self;

    ( $params, $attributes ) = $self->define_library_group_limits( $params, $attributes );

    return $self->SUPER::search( $params, $attributes );
}

=head2 Internal methods

=head3 _type (internal)

=cut

sub _type {
    return 'Aqbookseller';
}

=head3 object_class (internal)

=cut

sub object_class {
    return 'Koha::Acquisition::Bookseller';
}

1;
