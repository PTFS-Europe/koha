package Koha::ERM::UsageItem;

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

use Koha::ERM::YearlyUsage;
use Koha::ERM::YearlyUsages;
use Koha::ERM::MonthlyUsage;
use Koha::ERM::MonthlyUsages;

=head1 NAME

Koha::ERM::UsageItem - Koha ErmUsageItemObject class

=head1 API

=head2 Class Methods
=head3 erm_usage_muses

Method to embed erm_usage_muses to items for report formatting

=cut

sub erm_usage_muses {
    my ( $self ) = @_;
    my $usage_mus_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::MonthlyUsages->_new_from_dbic($usage_mus_rs);
}

=head3 erm_usage_yuses

Method to embed erm_usage_yuses to items for report formatting

=cut

sub erm_usage_yuses {
    my ( $self ) = @_;
    my $usage_yus_rs = $self->_result->erm_usage_yuses;
    return Koha::ERM::YearlyUsages->_new_from_dbic($usage_yus_rs);
}

=head3 yearly_usages

Getter/setter for yearly_usages for this item
Skips adding yearly_usage if it already exists

=cut

sub yearly_usages {
    my ( $self, $yearly_usages ) = @_;

    if ($yearly_usages) {
        for my $yearly_usage (@$yearly_usages) {
            next if $self->yearly_usages()->search($yearly_usage)->last;
            Koha::ERM::YearlyUsage->new($yearly_usage)->store;
        }
    }
    my $yearly_usages_rs = $self->_result->erm_usage_yuses;
    return Koha::ERM::YearlyUsages->_new_from_dbic($yearly_usages_rs);
}

=head3 monthly_usages

Getter/setter for monthly_usages for this item
Skips adding monthly_usage if it already exists

=cut

sub monthly_usages {
    my ( $self, $monthly_usages ) = @_;

    if ($monthly_usages) {
        for my $monthly_usage (@$monthly_usages) {
            next if $self->monthly_usages()->search($monthly_usage)->last;
            Koha::ERM::MonthlyUsage->new($monthly_usage)->store;
        }
    }
    my $monthly_usages_rs = $self->_result->erm_usage_muses;
    return Koha::ERM::MonthlyUsages->_new_from_dbic($monthly_usages_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'ErmUsageItem';
}

1;
