package Koha::ShibbolethConfigs;

use Modern::Perl;
use base qw(Koha::Objects);
use Koha::ShibbolethConfig;

=head1 NAME

Koha::ShibbolethConfigs - Koha ShibbolethConfig Object set class

=head1 API

=head2 Class Methods

=cut

=head3 get_configuration

Returns the Shibboleth configuration settings.
Always returns the single configuration row with ID=1.

=cut

sub get_configuration {
    my ($self) = @_;
    
    # Always get config with ID=1
    my $config = $self->find(1);
    unless ($config) {
        # Create default config with ID=1 if it doesn't exist
        $config = Koha::ShibbolethConfig->new({
            shibboleth_config_id => 1,
            enable_opac_sso => 0,
            enable_staff_sso => 0,
            autocreate => 0,
            sync => 0,
            welcome => 0
        })->store;
    }
    
    return $config;
}

=head3 _type

=cut

sub _type {
    return 'ShibbolethConfig';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::ShibbolethConfig';
}

1;
