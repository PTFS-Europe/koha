package Koha::REST::V1::Plugins;

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

use Mojo::Base 'Mojolicious::Controller';

use Archive::Extract;

use Koha::Plugins;
use C4::Context;

=head1 NAME

Koha::REST::V1::Plugins

=head1 API

=head2 Class methods

=head3 add

Installs the uploaded plugin

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->json;
    my $kpz_url = delete $body->{kpz_url} // [];

    use File::Fetch;
    my $ff = File::Fetch->new( uri => $kpz_url );
    my $file = $ff->fetch() or die $ff->error;

    my $mojo_file = Mojo::Asset::File->new( path => $file );

    my $uploadfile = $mojo_file->to_file;
    my $uploadfilename = $c->param('filename');


    my $plugins_restricted = C4::Context->config("plugins_restricted");
    my $plugins_dir        = C4::Context->config("pluginsdir");
    $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;

    my $dirname = File::Temp::tempdir( CLEANUP => 1 );

    my $filesuffix;
    $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
    my ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

    my %errors;
    $errors{'NOTKPZ'} = 1 if ( $uploadfilename !~ /\.kpz$/i );
    $errors{'NOWRITETEMP'}    = 1 unless ( -w $dirname );
    $errors{'NOWRITEPLUGINS'} = 1 unless ( -w $plugins_dir );

    $errors{'RESTRICTED'}  = 1 unless ( !$plugins_restricted );
    $errors{'EMPTYUPLOAD'} = 1 unless ( length($uploadfile) > 0 );

    my $ae = Archive::Extract->new( archive => $uploadfile->path, type => 'zip' );
    unless ( $ae->extract( to => $plugins_dir ) ) {
        warn "ERROR: " . $ae->error;
        $errors{'UZIPFAIL'} = $uploadfilename;
        exit;
    }

    # Install plugins; verbose not needed, we redirect to plugins-home.
    # FIXME There is no good way to verify the install below; we need an
    # individual plugin install.
    Koha::Plugins->new->InstallPlugins( { verbose => 0 } );


    return try {
        return $c->render(
            status  => 201,
            openapi => $kpz_url
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
