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
    return Koha::ShibbolethFieldMappings->new;
}

=head3 get_combined_config 

Returns complete configuration including mappings

=cut

sub get_combined_config {
    my ($self) = @_;
    
    my $config = $self->unblessed;
    my ($success, $mapping_config) = $self->mappings->get_mapping_config;
    
    if ($success) {
        # Merge mapping config with base config
        $config->{matchpoint} = $mapping_config->{matchpoint}; 
        $config->{mapping} = $mapping_config->{mapping};
        return $config;
    }
    
    return;
}

=head3 get_field_mappings

Returns a hashref of field mappings in config format

=cut

sub get_field_mappings {
    my ($self) = @_;
    my ($success, $mapping_config) = $self->mappings->get_mapping_config;
    return $mapping_config->{mapping} if $success;
    return {};
}

1;
