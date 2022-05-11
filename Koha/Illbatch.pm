package Koha::Illbatch;

# Copyright PTFS Europe 2022
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
use Koha::Database;
use base qw(Koha::Object);

=head1 NAME

Koha::Illbatch - Koha Illbatch Object class

=head2 Class methods

=head3 patron

    my $patron = Koha::Illbatch->patron;

Return the patron object associated with this batch

=cut

sub patron {
    my ( $self ) = @_;
    return Koha::Patron->_new_from_dbic(
        scalar $self->_result->borrowernumber
    );
}

=head3 branch

    my $branch = Koha::Illbatch->branch;

Return the branch object associated with this batch

=cut

sub branch {
    my ( $self ) = @_;
    return Koha::Library->_new_from_dbic(
        scalar $self->_result->branchcode
    );
}

=head3 requests_count

    my $requests_count = Koha::Illbatch->requests_count;

Return the number of requests associated with this batch

=cut

sub requests_count {
    my ( $self ) = @_;
    return Koha::Illrequests->search({
        batch_id => $self->id
    })->count;
}

=head2 Internal methods

=head3 _type

    my $type = Koha::Illbatch->_type;

Return this object's type

=cut

sub _type {
    return 'Illbatch';
}

=head1 AUTHOR

Andrew Isherwood <andrew.isherwood@ptfs-europe.com>

=cut

1;
