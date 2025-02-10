package Koha::Patron::Quotas;

use base qw(Koha::Objects);
use Modern::Perl;
use base qw(Koha::Objects);

use Koha::Patron::Quota;
use Koha::Patrons;

=head1 NAME

Koha::Patron::Quotas - Koha Patron Quota Object set class

=head1 API

=head2 Class Methods

=head3 create_quota

Creates a new quota record for a patron

=cut

sub create_quota {
    my ( $self, $params ) = @_;

    return Koha::Patron::Quota->new($params)->store;
}

=head3 filter_by_active

    $quotas->filter_by_active;

Returns the currently active quotas for the resultset.

Active means start_date <= NOW() and end_date >= NOW().

=cut

sub filter_by_active {
    my ($self) = @_;
    return $self->search(
        {
            start_date => { '<=' => \'NOW()' },
            end_date   => { '>=' => \'NOW()' },
        }
    );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronQuota';
}

=head3 object_class

Returns the package name for koha patron quota objects

=cut

sub object_class {
    return 'Koha::Patron::Quota';
}

1;
