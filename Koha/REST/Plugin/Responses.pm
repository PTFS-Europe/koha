package Koha::REST::Plugin::Responses;

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

use Mojo::Base 'Mojolicious::Plugin';

=head1 NAME

Koha::REST::Plugin::Responses

=head1 API

=head2 Helper methods

=cut

sub register {
    my ( $self, $app ) = @_;

=head3 render_resource_deleted

    $c->render_resource_deleted

Provides a generic method rendering the standard response for resource deletion.

=cut

    $app->helper(
        'render_resource_deleted' => sub {
            my ($c) = @_;

            $c->render(
                status  => 204,
                openapi => q{},
            );
        }
    );

=head3 render_resource_not_found

    $c->render_resource_not_found

Provides a generic method rendering the standard response for resource not found.

=cut

    $app->helper(
        'render_resource_not_found' => sub {
            my ( $c, $name ) = @_;

            my $message =
                ($name)
                ? "$name not found"
                : "Resource not found";

            $c->render(
                status  => 404,
                openapi => {
                    error      => $message,
                    error_code => 'not_found',
                },
            );
        }
    );
}

1;
