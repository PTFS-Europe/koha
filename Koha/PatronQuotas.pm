package Koha::PatronQuotas;

use Modern::Perl;
use Koha::PatronQuota;
use base qw(Koha::Objects);

=head1 NAME

Koha::PatronQuotas - Koha PatronQuota Object set class

=head1 API

=head2 Internal methods

=cut

sub _type {
    return 'PatronQuota';
}

sub object_class {
    return 'Koha::PatronQuota';
}

=head2 Class Methods

=head3 get_patron_quota

Returns the active quota for a given patron

=cut

sub get_patron_quota {
    my ($self, $patron_id) = @_;
    
    return $self->search({
        patron_id => $patron_id,
        period_start => {'<=' => \'CURRENT_DATE'},
        period_end => {'>=' => \'CURRENT_DATE'},
    })->single;
}

=head3 create_quota

Creates a new quota record for a patron

=cut

sub create_quota {
    my ($self, $params) = @_;
    
    return Koha::PatronQuota->new($params)->store;
}

=head3 search_by_patron

Finds all quotas for a patron

=cut

sub search_by_patron {
    my ($self, $patron_id) = @_;
    return $self->search({ patron_id => $patron_id });
}

=head3 get_active_quotas

Returns multiple active quota records

=cut

sub get_active_quotas {
    my ($self) = @_;
    return $self->search({
        period_start => {'<=' => \'CURRENT_DATE'},
        period_end => {'>=' => \'CURRENT_DATE'}
    });
}

1;