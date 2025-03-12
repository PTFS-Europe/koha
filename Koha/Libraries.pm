package Koha::Libraries;

# Copyright 2015 Koha Development team
#
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


use C4::Context;

use Koha::Biblios;
use Koha::Database;
use Koha::Item::Transfer::Limits;
use Koha::Items;
use Koha::Library;
use Koha::Patrons;

use base qw(Koha::Objects::Mixin::AdditionalFields Koha::Objects);

=head1 NAME

Koha::Libraries - Koha Library Object set class

=head1 API

=head2 Class methods

=head3 search_filtered

=cut

sub search_filtered {
    my ( $self, $params, $attributes ) = @_;

    my @branchcodes;
    my $userenv = C4::Context->userenv;
    if ( $userenv and $userenv->{number} ) {
        my $only_from_group = $params->{only_from_group};
        if ( $only_from_group ) {
            my $logged_in_user = Koha::Patrons->find( $userenv->{number} );
            my @branchcodes = $logged_in_user->libraries_where_can_see_patrons;
            $params->{branchcode} = { -in => \@branchcodes } if @branchcodes;
        } else {
            if ( C4::Context::only_my_library ) {
                $params->{branchcode} = C4::Context->userenv->{branch};
            }
        }
    }
    delete $params->{only_from_group};
    return $self->SUPER::search( $params, $attributes );
}

=head3 type

=cut

sub _type {
    return 'Branch';
}

sub object_class {
    return 'Koha::Library';
}

1;
