package Koha::ShibbolethFieldMappings;

use Modern::Perl;
use base qw(Koha::Objects);
use Koha::ShibbolethFieldMapping;
use Koha::Logger;

=head1 NAME

Koha::ShibbolethFieldMappings - Koha ShibbolethFieldMapping Object set class

=head1 API

=head2 Class Methods

=cut

=head3 ensure_single_matchpoint

Ensures only one matchpoint exists by clearing other matchpoints when setting a new one

=cut

sub ensure_single_matchpoint {
    my ($self, $new_matchpoint_id) = @_;
    
    return $self->search({
        is_matchpoint => 1,
        mapping_id => { '!=' => $new_matchpoint_id || 0 }
    })->update({ is_matchpoint => 0 });
}

=head3 get_matchpoint

Returns the field mapping that is set as the matchpoint

=cut

sub get_matchpoint {
    my ($self) = @_;
    my $matchpoint = $self->search({ is_matchpoint => 1 })->single;
    
    unless ($matchpoint) {
        Koha::Logger->get->warn('No matchpoint configured in Shibboleth field mappings');
    }
    
    return $matchpoint;
}

=head3 get_mapping_config

Returns the field mappings formatted for use in authentication configuration.

=cut

sub get_mapping_config {
    my ($self) = @_;
    
    my $mappings = {};
    my $matchpoint = $self->get_matchpoint;
    
    return (0, undef) unless $matchpoint;
    
    my $all_mappings = $self->search;
    while (my $mapping = $all_mappings->next) {
        $mappings->{$mapping->koha_field} = {
            is => $mapping->idp_field,
            content => $mapping->default_content,
        };
    }
    
    return (1, {
        matchpoint => $matchpoint->koha_field,
        mapping => $mappings
    });
}

=head3 _type

=cut

sub _type {
    return 'ShibbolethFieldMapping';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ShibbolethFieldMapping';
}

1;
