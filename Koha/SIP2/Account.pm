package Koha::SIP2::Account;

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

use Koha::SIP2::Institution;

=head1 NAME

Koha::ERM::Account- Koha SipAccount Object class

=head1 API

=head2 Class Methods

=cut

=head3 get_for_config

Returns the account hashref as expected by C4/SIP/Sip/Configuration->new;

=cut

sub get_for_config {
    my ( $self ) = @_;

    return {
        $self->ae_field_template ? ('ae_field_template' => $self->ae_field_template) : (),
        'id'                => $self->login_id,
        'delimiter'         => $self->delimiter,
        'error-detect'      => $self->error_detect,
        'institution'       => $self->institution->name,
        'password'          => $self->login_password,
        'terminator'        => $self->terminator,
    }
}

=head3 institution

Return the institution for this account

=cut

sub institution {
    my ( $self ) = @_;
    my $institution_rs = $self->_result->sip_institution;
    return unless $institution_rs;
    return Koha::SIP2::Institution->_new_from_dbic($institution_rs);
}

=head3 type

=cut

sub _type {
    return 'SipAccount';
}

1;
