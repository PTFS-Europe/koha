package Koha::Exceptions::Acquisition::FundManagement;

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

use Koha::Exception;

use Exception::Class (

    'Koha::Exceptions::Acquisition::FundManagement' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::Acquisition::FundManagement::LimitExceeded' => {
        isa         => 'Koha::Exceptions::Acquisition::FundManagement',
        description => 'Spend limit has been exceeded',
        fields      => [ 'data_type', 'amount' ]
    }
);

=head1 NAME

Koha::Exceptions::Acquisition::FundManagement - Base class for FundManagement exceptions

=head1 Exceptions

=head2 Koha::Exceptions::Acquisition::FundManagement

Generic Nasket exception

=head2 Koha::Exceptions::Acquisition::FundManagement::LimitExceeded

Exception to be used when a new fund allocation will breach a spending limit

=cut

1;
