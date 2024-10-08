package Koha::SFTP::Server;

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
use Koha::Exceptions::Object;
use Koha::Encryption;
use Koha::SFTP::Servers;

use base qw(Koha::Object);

=head1 NAME

Koha::SFTP::Server - Koha SFTP Server Object class

=head1 API

=head2 Class methods

=head3 store

    $server->store;

Overloaded store method.

=cut

sub store {
    my ($self) = @_;
    
    # catch password and encrypt it
    $self->password(
        $self->password
        ? Koha::Encryption->new->encrypt_hex( $self->password )
        : undef
    );

    return $self->SUPER::store;
}

=head3 to_api

    my $json = $sftp_server->to_api;

Overloaded method that returns a JSON representation of the Koha::SFTP::Server object,
suitable for API output.

=cut

sub to_api {
    my ( $self, $params ) = @_;

    my $json_sftp = $self->SUPER::to_api( $params );
    return unless $json_sftp;
    delete $json_sftp->{password};

    return $json_sftp;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::SFTP::Server object
on the API.

=cut

sub to_api_mapping {
    return {
        id => 'sftp_server_id'
    };
}

=head3 new

    $server->plain_text_password;
Fetches the plaintext password, from the object

=cut

sub plain_text_password {
    my ($self) = @_;

    return Koha::Encryption->new->decrypt_hex($self->password)
        if $self->password;

}

=head2 Internal methods

=head3 _type

Return type of Object relating to Schema ResultSet

=cut

sub _type {
    return 'SftpServer';
}

1;
