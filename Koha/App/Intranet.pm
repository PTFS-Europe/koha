package Koha::App::Intranet;

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

use Mojo::Base 'Mojolicious';

use Koha::Caches;
use Koha::Cache::Memory::Lite;

sub startup {
    my ($self) = @_;

    push @{$self->plugins->namespaces}, 'Koha::App::Plugin';
    push @{$self->static->paths}, $self->home->rel_file('koha-tmpl');

    # Create route for all CGI scripts, need to be loaded first because of
    # CGI::Compile
    $self->plugin('CGIBinKoha');

    # Create routes for API
    # FIXME This generates routes like this: /api/api/v1/...
    $self->plugin('RESTV1');

    $self->hook(before_dispatch => \&_before_dispatch);
    $self->hook(around_action => \&_around_action);

    my $r = $self->routes;

    $r->any('/')->to(cb => sub { shift->redirect_to('/cgi-bin/koha/mainpage.pl') });
}

sub _before_dispatch {
    my $c = shift;

    my $path = $c->req->url->path->to_string;

    # Remove Koha version from URL
    $path =~ s/_\d{2}\.\d{7}\.(js|css)/.$1/;

    # See FIXME above
    if ($path =~ m|^/api/v|) {
        $path = '/api' . $path;
    }

    $c->req->url->path->parse($path);
}

sub _around_action {
    my ($next, $c, $action, $last) = @_;

    # Flush memory caches before every request
    Koha::Caches->flush_L1_caches();
    Koha::Cache::Memory::Lite->flush();

    return $next->();
}

1;
