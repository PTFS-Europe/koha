package Koha::Patron::Quota;

use Modern::Perl;
use Koha::DateUtils qw( dt_from_string );
use Koha::Exceptions::Quota;
use base            qw(Koha::Object);

=head1 NAME

Koha::Patron::Quota - Koha Patron::Quota Object class

=head1 API

=head2 Class Methods

=head2 store

Overloaded store method to prevent creation of overlapping quota periods for a user

=cut

sub store {
    my ($self) = @_;

    # Parse dates into DateTime objects first
    my $start_dt = dt_from_string($self->period_start);
    my $end_dt = dt_from_string($self->period_end);

    # Throw exception for quota period clash
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $existing_quota = Koha::Patron::Quotas->search(
        {
            '-and' => [
                {
                    '-or' => [
                        period_start => {
                            '-between' => [
                                $dtf->format_datetime($start_dt),
                                $dtf->format_datetime($end_dt)
                            ]
                        },
                        period_end => {
                            '-between' => [
                                $dtf->format_datetime($start_dt),
                                $dtf->format_datetime($end_dt)
                            ]
                        },
                        {
                            period_start => { '<' => $dtf->format_datetime($start_dt) },
                            period_end   => { '>' => $dtf->format_datetime($end_dt) }
                        }
                    ]
                },
                {
                    patron_id => $self->patron_id,
                    (
                        $self->in_storage
                        ? ( quota_id => { '!=' => $self->quota_id } )
                        : ()
                    ),
                }
            ]
        }
    );
    Koha::Exceptions::Quota::Clash->throw()
        if $existing_quota->count;

    return $self->SUPER::store();
}

=head3 add_to_quota

Adds specified amount to the quota_used value

=cut

sub add_to_quota {
    my ( $self, $amount ) = @_;

    my $new_used = $self->quota_used + $amount;
    $self->quota_used($new_used);
    return $self->store;
}

=head3 has_available_quota

Returns boolean indicating if there is quota available

=cut

sub has_available_quota {
    my ($self) = @_;
    return $self->available_quota >= 0;
}

=head3 available_quota

Returns the amount still available in the quota

=cut

sub available_quota {
    my ($self) = @_;
    return $self->quota_total - $self->quota_used;
}

=head2 Instance Methods

=head3 get_patron

Returns the patron object associated with this quota

=cut

sub get_patron {
    my ($self) = @_;
    return Koha::Patrons->find( $self->patron_id );
}

=head3 is_active

Returns boolean indicating if the quota period includes today's date

=cut

sub is_active {
    my ($self) = @_;
    my $today = dt_from_string;

    my $start = DateTime->new(
        year  => substr( $self->period_start, 0, 4 ),
        month => substr( $self->period_start, 5, 2 ),
        day   => substr( $self->period_start, 8, 2 )
    );

    my $end = DateTime->new(
        year  => substr( $self->period_end, 0, 4 ),
        month => substr( $self->period_end, 5, 2 ),
        day   => substr( $self->period_end, 8, 2 )
    );

    return ( $start <= $today && $end >= $today );
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronQuota';
}

1;
