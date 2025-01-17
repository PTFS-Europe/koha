package Koha::ILL::Backends;

# Copyright PTFS Europe 2023
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

use Koha::ILL::Request::Config;

use base qw(Koha::Objects);

=head1 NAME

Koha::ILL::Backends - Koha Illbackends Object class

=head2 Class methods

=head3 new

New ILL Backend

=cut

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

=head3 installed_backends

Return a list of installed backends.

=cut

sub installed_backends {
    my $backends  = Koha::ILL::Request::Config->new->available_backends;
    my @installed = grep { !/Standard/ } @{$backends};
    return \@installed;
}

=head3 opac_available_backends

Return a list of backends available in the OPAC

=cut

sub opac_available_backends {
    my ( $self, $loggedinuser ) = @_;
    my $reduced  = C4::Context->preference('ILLOpacbackends');
    my $backends = Koha::ILL::Request::Config->new->available_backends($reduced);

    if ( !$loggedinuser && C4::Context->preference('ILLOpacUnauthenticatedRequest') ) {
        $backends = [
            grep {
                my $loaded_b = Koha::ILL::Request->new->load_backend($_);
                $loaded_b->_backend_capability('opac_unauthenticated_ill_requests')
            } @$backends
        ];
    }

    return $backends;
}

=head2 Internal methods

=head3 _type

    my $type = Koha::ILL::Backend->_type;

Return this object's type

=cut

sub _type {
    return 'Illbackend';
}

=head1 AUTHOR

Pedro Amorim <pedro.amorim@ptfs-europe.com>

=cut

1;
