package Koha::REST::V1::Acquisitions::Baskets;

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

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny qw( catch try );

use C4::Acquisition qw( CanUserManageBasket );

=head1 NAME

Koha::REST::V1::Acquisitions::Baskets

=head1 API

=head2 Class methods

=head3 list

Controller function that handles baskets

=cut

=head3 list_managers

Return the list of possible orders' managers

=cut

sub list_managers {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $patrons_rs = Koha::Patrons->search->filter_by_have_permission('acquisition.order_manage');
        my $patrons    = $c->objects->search($patrons_rs);

        return $c->render(
            status  => 200,
            openapi => $patrons
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 list

Return a list of baskets

=cut

sub list {
    my $c      = shift->openapi->valid_input or return;
    my $patron = $c->stash('koha.user');

    return try {

        my $baskets_rs = Koha::Acquisition::Baskets->new;
        my $baskets    = $c->objects->search($baskets_rs);

        my $userflags = C4::Auth::getuserflags( $patron->flags, $patron->userid );

        my @user_baskets;
        foreach my $basket (@$baskets) {
            my $success = CanUserManageBasket( $patron->unblessed, $basket, $userflags );
            push @user_baskets, $basket if $success;
        }

        return $c->render(
            status  => 200,
            openapi => \@user_baskets
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
