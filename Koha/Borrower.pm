package Koha::Borrower;

# Copyright ByWater Solutions 2014
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

use base qw(Koha::Object);

use Koha::Borrower::Categories;
use Koha::Borrower::ILLRequests;

=head1 NAME

Koha::Borrower - Koha Borrower Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'Borrower';
}

=head3 Category

Returns the related Koha::Borrower::Category object for this Borrower

=cut

sub Category {
    my ($self) = @_;

    $self->{Category} ||= Koha::Borrower::Categories->new()->find( $self->categorycode() );

    return $self->{Category};
}

=head3 ILLRequests

Returns the related Koha::Borrower::ILLRequests object for this Borrower

=cut

sub ILLRequests {
    my ($self) = @_;

    $self->{ILLRequests} ||= Koha::Borrower::ILLRequests->new()->search( { 'borrowernumber' => $self->borrowernumber() } );

    return $self->{ILLRequests};
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>
Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
