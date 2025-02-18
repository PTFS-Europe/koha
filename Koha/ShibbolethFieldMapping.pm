package Koha::ShibbolethFieldMapping;

use Modern::Perl;
use Koha::Exceptions;
use base qw(Koha::Object);

=head1 NAME

Koha::ShibbolethFieldMapping - Koha ShibbolethFieldMapping Object class

=head1 API

=head2 Class Methods

=cut

=head3 store

Override the base store method to enforce business rules:
- Only one matchpoint can be set at a time
- Required fields must be present

=cut

sub store {
    my $self = shift;

    # Validate required fields
    unless ($self->idp_field && $self->koha_field) {
        Koha::Exceptions::MissingParameter->throw(
            error => "Both idp_field and koha_field are required"
        );
    }

    # Handle matchpoint logic using plural class
    if ($self->is_matchpoint) {
        Koha::ShibbolethFieldMappings->new->ensure_single_matchpoint($self->mapping_id);
    }

    return $self->SUPER::store(@_);
}

=head3 _type

=cut

sub _type {
    return 'ShibbolethFieldMapping';
}

1;
