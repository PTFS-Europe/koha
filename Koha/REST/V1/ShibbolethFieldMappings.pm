package Koha::REST::V1::ShibbolethFieldMappings;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny qw(catch try);

=head3 list

List all field mappings

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mappings = $c->objects->search( Koha::ShibbolethFieldMappings->new );
        return $c->render( status => 200, openapi => $mappings );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 get

Get a specific mapping

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mapping = Koha::ShibbolethFieldMappings->find( $c->param('mapping_id') );
        
        return $c->render_resource_not_found('Mapping not found') unless $mapping;
        
        return $c->render( status => 200, openapi => $c->objects->to_api($mapping) );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Add a new field mapping

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mapping = Koha::ShibbolethFieldMapping->new_from_api($c->req->json);
        $mapping->store;
        
        return $c->render(
            status => 201,
            openapi => $c->objects->to_api($mapping)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 update 

Update an existing mapping

=cut

sub update {
    my $c = shift->openapi->valid_input or return;
    
    return try {
        my $mapping = Koha::ShibbolethFieldMappings->find($c->param('mapping_id'));
        
        return $c->render_resource_not_found('Mapping not found') unless $mapping;
        
        $mapping->set_from_api($c->req->json)->store;
        
        return $c->render(
            status => 200,
            openapi => $c->objects->to_api($mapping)
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

=head3 delete

Delete a mapping

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $mapping = Koha::ShibbolethFieldMappings->find($c->param('mapping_id'));
        
        return $c->render_resource_not_found('Mapping not found') unless $mapping;
        
        $mapping->delete;
        return $c->render_resource_deleted;
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
