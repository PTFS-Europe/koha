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

=head3 get_patron_quota

    my $quota = Koha::Patron::Quotas->get_patron_quota($patron_id);

Searches for any applicable quota for the given patron. Returns:
- First available quota found for patron or their guarantor (if UseGuarantorQuota enabled)
- If no available quota found, returns the first found quota
- Returns undef if no quota found

=cut

sub get_patron_quota {
    my ( $self, $patron_id ) = @_;

    my @available_quotas;
    my $first_found_quota = undef;

    # First check patron's own quota
    my $patron_quota = $self->search(
        {
            patron_id  => $patron_id,
            start_date => { '<=' => \'CURRENT_DATE' },
            end_date   => { '>=' => \'CURRENT_DATE' }
        }
    )->single;

    if ( $patron_quota && $patron_quota->has_available_quota ) {
        push @available_quotas, $patron_quota;
    }
    $first_found_quota ||= $patron_quota if $patron_quota;

    # Then check all guarantor quotas if enabled
    if ( C4::Context->preference('UseGuarantorQuota') ) {
        my $patron     = Koha::Patrons->find($patron_id);
        my @guarantors = $patron->guarantor_relationships->guarantors->as_list;

        foreach my $guarantor (@guarantors) {
            my $guarantor_quota = $self->search(
                {
                    patron_id  => $guarantor->borrowernumber,
                    start_date => { '<=' => \'CURRENT_DATE' },
                    end_date   => { '>=' => \'CURRENT_DATE' }
                }
            )->single;

            if ($guarantor_quota) {

                # Store first found quota in case we need it later
                $first_found_quota ||= $guarantor_quota;

                # Collect available guarantor quotas
                if ( $guarantor_quota->has_available_quota ) {
                    push @available_quotas, $guarantor_quota;
                }
            }
        }
    }

    # Return single quota if only one available, array of quotas if multiple available,
    # first found quota if none available
    return $available_quotas[0] if @available_quotas == 1;
    return \@available_quotas   if @available_quotas > 1;
    return $first_found_quota;
}

=head3 create_quota

Creates a new quota record for a patron

=cut

sub create_quota {
    my ( $self, $params ) = @_;

    return Koha::Patron::Quota->new($params)->store;
}

=head3 search_by_patron

Finds all quotas for a patron

=cut

sub search_by_patron {
    my ( $self, $patron_id ) = @_;
    return $self->search( { patron_id => $patron_id } );
}

=head3 get_active_quotas

Returns multiple active quota records

=cut

sub get_active_quotas {
    my ($self) = @_;
    return $self->search(
        {
            start_date => { '<=' => \'CURRENT_DATE' },
            end_date   => { '>=' => \'CURRENT_DATE' }
        }
    );
}

=head2 get_active_quota

  my $active_quota = Koha::Patron::Quotas->get_active_quota($patron_id);

Returns the currently active quota for a patron if one exists.
Active means start_date <= NOW() and end_date >= NOW().
Returns undef if no active quota found.

=cut

sub get_active_quota {
    my ( $self, $patron_id ) = @_;

    return Koha::Patron::Quotas->search(
        {
            patron_id  => $patron_id,
            start_date => { '<=' => \'CURRENT_DATE' },
            end_date   => { '>=' => \'CURRENT_DATE' }
        }
    )->single;
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
