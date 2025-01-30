package Koha::Patron::Quota;

use Modern::Perl;
use Koha::DateUtils qw( dt_from_string );
use Koha::Exceptions::Quota;
use base qw(Koha::Object);

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
    my $start_dt = dt_from_string( $self->start_date );
    my $end_dt   = dt_from_string( $self->end_date );

    # Throw exception for quota period clash
    my $dtf            = Koha::Database->new->schema->storage->datetime_parser;
    my $existing_quota = Koha::Patron::Quotas->search(
        {
            '-and' => [
                {
                    '-or' => [
                        start_date => {
                            '-between' => [
                                $dtf->format_datetime($start_dt),
                                $dtf->format_datetime($end_dt)
                            ]
                        },
                        end_date => {
                            '-between' => [
                                $dtf->format_datetime($start_dt),
                                $dtf->format_datetime($end_dt)
                            ]
                        },
                        {
                            start_date => { '<' => $dtf->format_datetime($start_dt) },
                            end_date   => { '>' => $dtf->format_datetime($end_dt) }
                        }
                    ]
                },
                {
                    patron_id => $self->patron_id,
                    (
                        $self->in_storage
                        ? ( id => { '!=' => $self->id } )
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
        year  => substr( $self->start_date, 0, 4 ),
        month => substr( $self->start_date, 5, 2 ),
        day   => substr( $self->start_date, 8, 2 )
    );

    my $end = DateTime->new(
        year  => substr( $self->end_date, 0, 4 ),
        month => substr( $self->end_date, 5, 2 ),
        day   => substr( $self->end_date, 8, 2 )
    );

    return ( $start <= $today && $end >= $today );
}

=head3 to_api

=cut

sub to_api {
    my ( $self, $args ) = @_;
    return $self->SUPER::to_api($args);
}

=head3 set_from_api

=cut

sub set_from_api {
    my ( $self, $data ) = @_;
    return $self->SUPER::set_from_api($data);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronQuota';
}

1;
