package Koha::REST::V1::Patrons::Quotas;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use Koha::Patron::Quotas;

use Try::Tiny qw( catch try );

=head1 API

=head2 Methods

=head3 list

Controller method for listing patron quotas

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron_id = $c->param('patron_id'); 
        my $only_active = $c->param('only_active');

        # Remove params we've handled
        $c->req->params->remove('patron_id')->remove('only_active');

        my $quotas_set = Koha::Patron::Quotas->new;

        if ($patron_id) {
            $quotas_set = $quotas_set->search({ patron_id => $patron_id });
        }

        if ($only_active) {
            $quotas_set = $quotas_set->get_active_quotas;
        }

        return $c->render(
            status => 200,
            openapi => $c->objects->search($quotas_set)
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Controller method for retrieving a single quota

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $quota = Koha::Patron::Quotas->find( $c->param('quota_id') );
        
        return $c->render_resource_not_found("Quota") unless $quota;

        return $c->render( status => 200, openapi => $c->objects->to_api($quota) );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller method for adding a new quota

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->req->json;
        $body->{patron_id} = $c->param('patron_id');
        
        my $quota = Koha::Patron::Quota->new_from_api($body);
        $quota->store;

        $c->res->headers->location($c->req->url->to_string . '/' . $quota->quota_id);
        return $c->render(
            status  => 201,
            openapi => $c->objects->to_api($quota)
        );
    }
    catch {
        if (ref($_) eq 'Koha::Exceptions::Quota::Clash') {
            return $c->render(
                status  => 409,
                openapi => { error => "Quota period overlaps with existing quota" }
            );
        }
        $c->unhandled_exception($_);
    };
}

=head3 update

Controller method for updating a quota

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $quota = Koha::Patron::Quotas->find($c->param('quota_id'));
    
    return $c->render_resource_not_found("Quota") unless $quota;

    return try {
        $quota->set_from_api($c->req->json);
        $quota->store;
        return $c->render(status => 200, openapi => $c->objects->to_api($quota));
    }
    catch {
        if (ref($_) eq 'Koha::Exceptions::Quota::Clash') {
            return $c->render(
                status  => 409,
                openapi => { error => "Quota period overlaps with existing quota" }
            );
        }
        $c->unhandled_exception($_);
    };
}

=head3 delete

Controller method for deleting a quota

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $quota = Koha::Patron::Quotas->find($c->param('quota_id'));
    
    return $c->render_resource_not_found("Quota") unless $quota;

    return try {
        $quota->delete;
        return $c->render_resource_deleted;
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
