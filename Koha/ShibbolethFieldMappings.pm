package Koha::ShibbolethFieldMappings;

use Modern::Perl;
use base qw(Koha::Objects);

=head1 NAME

Koha::ShibbolethFieldMappings - Koha ShibbolethFieldMappings Object set class

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
    return $self->search({ is_matchpoint => 1 })->single;
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
