package Koha::App::Plugin::CGIBinKoha;

# Copyright 2020 BibLibre
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

use Mojo::Base 'Mojolicious::Plugin';

use CGI::Compile;
use CGI::Emulate::PSGI;
use IO::Scalar;

sub register {
    my ($self, $app, $conf) = @_;

    my $opac = $conf->{opac};

    my $r = $app->routes;

    $r->any('/cgi-bin/koha/*script' => sub {
        my ($c) = @_;

        my $script = $c->stash('script');

        # Special case for installer which can takes a long time
        $c->inactivity_timeout(300) if $script eq 'installer/install.pl';

        # Remove trailing slash, if any (e.g. .../svc/config/systempreferences/)
        $script =~ s|/$||;

        if ($opac) {
            $script = "opac/$script";
        }

        unless (-e $c->app->home->rel_file($script)) {
            return $c->reply->not_found;
        }

        my $sub = CGI::Compile->compile($script);
        my $app = CGI::Emulate::PSGI->handler($sub);
        my $response = $app->($self->_psgi_env($c));

        $c->res->code($response->[0]);
        $c->res->headers->from_hash({ @{ $response->[1] } });
        $c->res->body(join('', @{$response->[2]}));
        $c->rendered;
    })->name('cgi');
}

sub _psgi_env {
    my ($self, $c) = @_;

    my $env = $c->req->env;

    my $body = $c->req->build_body;
    $env = {
        %$env,
        'psgi.input' => IO::Scalar->new(\$body),
        'psgi.errors' => *STDERR,
        REQUEST_METHOD => $c->req->method,
        QUERY_STRING => $c->req->url->query->to_string,
        SERVER_NAME => $c->req->url->to_abs->host,
        SERVER_PORT => $c->req->url->to_abs->port,
        SERVER_PROTOCOL => 'HTTP/1.1',
        CONTENT_LENGTH => $c->req->headers->content_length,
        CONTENT_TYPE => $c->req->headers->content_type,
        REMOTE_ADDR => $c->tx->remote_address,
        SCRIPT_NAME => $c->req->url->path->to_string,
    };

    # Starman sets PATH_INFO to the same value of SCRIPT_NAME, which confuses
    # CGI and causes the redirect after OPAC login to fail
    delete $env->{PATH_INFO} if ($env->{PATH_INFO} && $env->{PATH_INFO} eq $env->{SCRIPT_NAME});

    for my $name (@{ $c->req->headers->names }) {
        my $value = $c->req->headers->header($name);
        $name =~ s/-/_/g;
        $name = 'HTTP_' . uc($name);
        $env->{$name} = $value;
    }

    return $env;
}

1;
