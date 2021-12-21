package Koha::Bookings;

# Copyright PTFS Europe 2021
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
use Koha::DateUtils qw(dt_from_string);

use Koha::Booking;

use base qw(Koha::Objects);

=head1 NAME

Koha::Bookings - Koha Booking object set class

=head1 API

=head2 Class Methods

=head3 filter_by_active

    Koha::Bookings->filter_by_active;

Returns set of Koha bookings objects that are currently active.

Active is defined as having a end date in the future.

=cut

sub filter_by_active {
    my ($self) = @_;

    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $now = dt_from_string();

    return $self->search(
        {
            end_date => { '>=' => $dtf->format_datetime($now) }
        }
    );
}

=head3 type

=cut

sub _type {
    return 'Booking';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Booking';
}

=head1 AUTHOR

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut

1;
