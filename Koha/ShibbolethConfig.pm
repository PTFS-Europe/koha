package Koha::ShibbolethConfig;

use Modern::Perl;
use base qw(Koha::Object);

=head1 NAME

Koha::ShibbolethConfig - Koha ShibbolethConfig Object class

=head1 API

=head2 Class Methods

=cut

=head3 _type

=cut

sub _type {
    return 'ShibbolethConfig';
}

=head3 store

Override store method to ensure we always update the single config row

=cut

sub store {
    my ($self) = @_;
    
    # Force ID to be 1
    $self->shibboleth_config_id(1);
    
    # If record exists, update it
    if (my $existing = Koha::ShibbolethConfigs->find(1)) {
        foreach my $field (qw( enable_opac_sso enable_staff_sso autocreate sync welcome )) {
            $existing->$field($self->$field) if $self->$field;
        }
        return $existing->SUPER::store();
    }
    
    # Otherwise create new record with ID 1
    return $self->SUPER::store();
}

=head3 mappings

Returns field mappings associated with this config

=cut

sub mappings {
    my ($self) = @_;
    
    # Create new ShibbolethFieldMappings object properly
    my $mappings = Koha::ShibbolethFieldMappings->new;
    return $mappings->search;  # Return the resultset directly
}

=head3 get_field_mappings

Returns a hashref of field mappings in config format

=cut

sub get_field_mappings {
    my ($self) = @_;
    
    my $mappings_rs = $self->mappings;  # Get the DBIx resultset
    my $map_config = {};
    
    while (my $mapping = $mappings_rs->next) {
        $map_config->{$mapping->koha_field} = {
            is => $mapping->idp_field
        };
    }
    
    return $map_config;
}

1;
