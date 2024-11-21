package Koha::Acquisition::FundManagement::SubFunds;

# Copyright 2024 PTFS Europe

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
use base qw(Koha::Objects Koha::Objects::Limit::LibraryGroup);

use Koha::Acquisition::FundManagement::SubFund;

=head1 NAME

Koha::Acquisition::FundManagement::SubFunds object set class

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

=head3 _type

=cut

sub _type {
    return 'SubFund';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Acquisition::FundManagement::SubFund';
}

1;
