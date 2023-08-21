package Koha::Exceptions::ERM::UsageStatistics;

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

    'Koha::Exceptions::ERM::UsageStatistics' => {
        isa => 'Koha::Exception',
    },
    'Koha::Exceptions::ERM::UsageStatistics::UnsupportedCOUNTERRelease' => {
        isa => 'Koha::Exceptions::ERM::UsageStatistics',
        description => 'This COUNTER release is not supported'
    },
    'Koha::Exceptions::ERM::UsageStatistics::ReportNotSupported' => {
        isa         => 'Koha::Exceptions::ERM::UsageStatistics',
        description => 'This report type is not supported'
    },
);

=head1 NAME

Koha::Exceptions::ERM::UsageStatistics - Base class for UsageStatistics exceptions

=head1 Exceptions


=head2 Koha::Exceptions::ERM::UsageStatistics

Generic UsageStatistics exception

=head2 Koha::Exceptions::ERM::UsageStatistics::UnsupportedRelease

Exception to be used when a report is submit with an unsupported COUNTER release

=cut

1;
