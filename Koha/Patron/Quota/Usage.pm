package Koha::Patron::Quota::Usage;

use Modern::Perl;

use base qw(Koha::Object);
use Koha::Patron::Quota;
use Koha::Patron::Quota::Usages;

=head1 NAME

Koha::Patron::Quota::Usage - Koha Patron Quota Usage Object class

=head1 API

=head2 Class methods

=cut

sub _type {
    return 'PatronQuotaUsage';
}

=head3 patron

Returns the patron this quota usage belongs to

=cut

sub patron {
    my ($self) = @_;
    my $rs = $self->_result->patron;
    return Koha::Patron->_new_from_dbic($rs);
}

=head3 quota

Returns the quota this usage belongs to

=cut

sub quota {
    my ($self) = @_;
    my $rs = $self->_result->patron_quota;
    return Koha::Patron::Quota->_new_from_dbic($rs);
}

sub store {
    my ($self) = @_;

    # Check that we have a valid issue_id
    unless ( !$self->issue_id
        || Koha::Checkouts->find( $self->issue_id )
        || Koha::Old::Checkouts->find( $self->issue_id ) )
    {
            Koha::Exceptions::Object::FKConstraint->throw(
                error     => 'Broken FK Contraint',
                broken_fk => 'issue_id'
            );
    }

    return $self->SUPER::store();
}

=head2 Internal methods

=head3 _type

=cut

1;
