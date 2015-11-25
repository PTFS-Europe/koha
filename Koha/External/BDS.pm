package Koha::External::BDS;

# Copyright 2015 PTFS-Europe Ltd
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

use strict;
use warnings;

use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;
# This is ripe for caching.. the auth token should be cached for the returned timeout period,
# and the isbn search results should be cached for, say 20 minutes, to catch a browsing around
# the results session.

sub fetch {
    my ($isbns) = @_;
    my $responses;

    # Non-blocking request
    Mojo::IOLoop->delay(
        sub {
            my $delay = shift;
            my $auth  = $ua->post(
                'https://api.bibdsl.co.uk/token' => form => {
                    grant_type => 'password',
                    username   => 'Cheshire',
                    password   => '5*DZRhe:'
                } => $delay->begin
            );
        },
        sub {
            my ( $delay, $auth ) = @_;
            Mojo::Exception->throw( $auth->error->{message} ) if $auth->error;

            my $token  = "Bearer " . $auth->success->json('/access_token');
            my $accept = 'application/json';

            for my $isbn ( @{$isbns} ) {
                $ua->get(
"https://api.bibdsl.co.uk/odata/v1/Products?\$filter=barcode eq \'"
                      . $isbn
                      . "\'" =>
                      { Authorization => $token, Accept => $accept } =>
                      $delay->begin );
            }
        },
        sub {
            my ($delay) = shift;
            for my $i ( 1 .. scalar @{$isbns} ) {
                my $response = shift;
                warn "Error in DBS Service: " . Dumper($response->error->{message})
                  if $response->error;

                my $response_json;
                $response_json = $response->success->json if $response->success;
                if ($response_json) {
                    $responses->{ $response_json->{'value'}[0]->{'barcode'} } =
                      $response_json->{'value'}[0];
                }
            }
        }
    )->catch( sub { warn "Exception thrown in BDS.pm" } )->wait;
    return $responses;
}

1;
