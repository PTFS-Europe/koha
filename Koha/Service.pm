package Koha::Service;

# This file is part of Koha.
#
# Copyright (C) 2014 ByWater Solutions
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

=head1 NAME

Koha::Service - base class for webservices.

=head1 SYNOPSIS

package Koha::Service::Frobnicator;

use base 'Koha::Service';

sub new {
    my ( $class ) = @_;

    return $class::SUPER::new( { frobnicate => 1 } );
}

sub run {
    my ( $self ) = @_;

    my ( $query, $cookie ) = $self->authenticate;
    my ( $borrowernumber ) = $self->require_params( 'borrowernumber' );

    $self->croak( 'internal', 'Frobnication failed', { frobnicator => 'foo' } );

    $self->output({ frobnicated => 'You' });
}

Koha::Service::Frobnicator->new->run;

=head1 DESCRIPTION

This module serves as a base class with utility methods for JSON webservices.

=head1 METHODS

=cut

use Modern::Perl;

use base 'Class::Accessor';

use C4::Auth qw( check_api_auth );
use C4::Context;
use C4::Output qw( :ajax );
use CGI;
use DateTime;
use JSON;

our $debug;

BEGIN {
    $debug = $ENV{DEBUG} || 0;
}

__PACKAGE__->mk_accessors( qw( auth_status query cookie ) );

=head2 new

    my $self = $class->SUPER::new( \%options );

Base constructor for a service.

C<\%options> may contain the following:

=over

=item authnotrequired

Defaults to false. If set, means that C<handle_auth_failure> will not croak if the user is not logged in.

=item needed_flags

Takes a hashref of required permissions, i.e., { circulation =>
'circulate_remaining_permissions' }.

=item routes

An arrayref of routes; see C<add_routes> for the required format.

=back

=cut

sub new {
    my ( $class, $options ) = @_;

    return bless {
        authnotrequired => 0,
        needed_flags => { catalogue => 1 },
        routes => [],
        %$options
    }, $class;
}

=head2 test

    $service->test( $request_method, $path_info, \%params );

Sets up a fake CGI context for unit tests.

=cut

sub test {
    my ( $self, $request_method, $path_info, $params ) = @_;

    $ENV{REQUEST_METHOD} = $request_method;
    $ENV{PATH_INFO} = $path_info;
    $ENV{HTTP_CONTENT_LENGTH} = "0";
    $self->query(CGI->new);

    foreach my $key ( keys %$params ) {
        $self->query->param( $key, $params->{ $key } );
    }

    my $user     = $ENV{KOHA_USER} || C4::Context->config("user");
    my $password = $ENV{KOHA_PASS} || C4::Context->config("pass");

    $self->query->param( 'userid', $user );
    $self->query->param( 'password', $password );

    $self->authenticate;
}

=head2 authenticate

    my ( $query, $cookie ) = $self->authenticate();

Authenticates the user and returns a C<CGI> object and cookie. May exit after sending an 'auth'
error if the user is not logged in or does not have the right permissions.

This must be called before the C<croak> or C<output> methods.

=cut

sub authenticate {
    my ( $self ) = @_;

    unless ( defined( $self->auth_status ) ) {
        $self->query(CGI->new) unless ( $self->query );

        my ( $status, $cookie, $sessionID ) = check_api_auth( $self->query, $self->{needed_flags} );
        $self->cookie($cookie);
        $self->auth_status($status);
        $self->handle_auth_failure() if ( $status ne 'ok' );
    }

    return ( $self->query, $self->cookie );
}

=head2 handle_auth_failure

    $self->handle_auth_failure();

Called when C<authenticate> fails (C<$self->auth_status> not 'ok'). By default, if
C<$self->{authnotrequired}> is not set, croaks and outputs an auth error.

=cut

sub handle_auth_failure {
    my ( $self ) = @_;

    $self->croak( 'auth', $self->auth_status ) if ( !$self->{authnotrequired} );
}

=head2 output

    $self->output( $response[, \%options] );

Outputs C<$response>, with the correct headers.

C<\%options> may contain the following:

=over

=item status

The HTTP status line to send; defaults to '200 OK'. This parameter is ignored for JSONP, as a
non-200 response cannot be easily intercepted.

=item type

Either 'js', 'json', 'xml' or 'html'. Defaults to 'json'. If 'json', and the C<callback> query parameter
is given, outputs JSONP.

=back

=cut

*DateTime::TO_JSON = sub { shift->_stringify; };

sub output {
    my ( $self, $response, $options ) = @_;

    binmode STDOUT, ':encoding(UTF-8)';

    # Set defaults
    $options = {
        status => '200 OK',
        type => 'json',
        %{ $options || {} },
    };

    if ( $options->{type} eq 'json' ) {
        $response = JSON->new->allow_blessed(1)->convert_blessed(1)->encode($response);

        if ( $self->query->param( 'callback' ) ) {
            $response = $self->query->param( 'callback' ) . '(' . $response . ');';
            $options->{status} = '200 OK';
            $options->{type} = 'js';
        }
    }

    output_with_http_headers $self->query, $self->cookie, $response, $options->{type}, $options->{status};
}

=head2 croak

    $self->croak( $error[, $detail[, \%flags]] );

Outputs an error as JSON, then exits the service with HTTP status 400.

C<$error> should be a short, lower case code for the generic type of error (such
as 'auth' or 'input').

C<$detail> should be a more specific code giving information on the error. If
multiple errors of the same type occurred, they should be joined by '|'; i.e.,
'expired|different_ip'. Information in C<$error> does not need to be
human-readable, as its formatting should be handled by the client.

Any additional information to be given in the response should be passed in \%flags.

The final result of this is a JSON structure like so:

    { "error": "$error", "detail": "$detail", ... }

=cut

sub croak {
    my ( $self, $error, $detail, $flags ) = @_;

    my $response = $flags || {};

    $response->{error} = $error;
    $response->{detail} = $detail;

    $self->output( $response, { status => '400 Bad Request' } );
    exit;
}

=head2 require_params

    my @values = $self->require_params( @params );

Check that each of of the parameters specified in @params was sent in the
request, then return their values in that order.

If a required parameter is not found, send a 'param' error to the browser.

=cut

sub require_params {
    my ( $self, @params ) = @_;

    my @values;

    for my $param ( @params ) {
        $self->croak( 'params', "missing_$param" ) if ( !defined( $self->query->param( $param ) ) );
        push @values, $self->query->param( $param );
    }

    return @values;
}

=head2 add_routes

    $self->add_routes(
        [ $path_regex, $handler[, \@required_params] ],
        ...
    );

Adds several routes, each described by an arrayref.

$path_regex should be a regex passed through qr//, describing which methods and
paths this route handles. Each route is tested in order, from the top down, so
put more specific handlers first. Also, the regex is tested on the request
method, plus the path. For instance, you might use the route [ qr'POST /', ... ]
to handle POST requests to your service.

$handler should be the name of a method in the current class.

If \@required_params is passed, each named parameter in it is tested to make sure the route matches.
No error is raised if one is missing; it simply tests the next route. If you would prefer to raise
an error, instead use C<require_params> inside your handler.

=cut

sub add_routes {
    my $self = shift;

    push @{ $self->{routes} }, @_;
}

=sub dispatch

    $self->dispatch();

Dispatches to the correct route for the current URL and parameters, or raises a 'no_handler' error.

$self->$handler is called with each matched group in $path_regex in its arguments. For
example, if your service is accessed at the path /blah/123, and you call
C<dispatch> with the route [ qr'GET /blah/(\d+)', ... ], your handler will be called
with the arguments '123'. The original C<CGI> object and cookie are available as C<$self->query> and C<$self->cookie>.

Returns the result of the matching handler.

=cut

sub dispatch {
    my $self = shift;

    my $path_info = $self->query->path_info || '/';

    ROUTE: foreach my $route ( @{ $self->{routes} } ) {
        my ( $path, $handler, $params ) = @$route;

        next unless ( my @match = ( ($self->query->request_method . ' ' . $path_info) =~ m,^$path$, ) );

        for my $param ( @{ $params || [] } ) {
            next ROUTE if ( !defined( $self->query->param ( $param ) ) );
        }

        $debug and warn "Using $handler for $path";
        return $self->$handler( @match );
    }

    $self->croak( 'no_handler' );
}

=sub run

    $service->run();

Runs the service. By default, calls authenticate, dispatch then output, but can be overridden.

=cut

sub run {
    my ( $self ) = @_;

    $self->authenticate;
    my $result = $self->dispatch;
    $self->output($result) if ($result);
}

1;
