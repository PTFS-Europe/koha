package Koha::REST::V1::ShibbolethConfig;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny qw(catch try);

=head3 get

Get the Shibboleth configuration

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $config = Koha::ShibbolethConfigs->new->get_configuration;
        return $c->render( status => 200, openapi => $c->objects->to_api($config) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update

Update Shibboleth configuration

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $config = Koha::ShibbolethConfigs->new->get_configuration;
        $config->set_from_api($c->req->json)->store;
        
        return $c->render( status => 200, openapi => $c->objects->to_api($config) );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
