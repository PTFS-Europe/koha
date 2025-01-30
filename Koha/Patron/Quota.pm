package Koha::Patron::Quota;

use base qw(Koha::Object);
use Modern::Perl;
use Koha::DateUtils qw( dt_from_string );
use Koha::Patron::Quotas;
use Koha::Exceptions::Quota;

=head1 NAME

Koha::Patron::Quota - Koha Patron::Quota Object class

=head1 API

=head2 Class Methods

=head3 store

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

    $amount //= 1;
    my $new_used = $self->used + $amount;
    $self->used($new_used);
    return $self->store;
}

=head3 has_available_quota

Returns boolean indicating if there is quota available

=cut

sub has_available_quota {
    my ($self) = @_;
    return $self->available_quota >= 1;
}

=head3 available_quota

Returns the amount still available in the quota

=cut

sub available_quota {
    my ($self) = @_;
    return $self->allocation - $self->used;
}

=head2 Instance Methods

=head3 patron

Returns the Koha::Patron associated with this quota

=cut

sub patron {
    my ($self) = @_;
    return Koha::Patron->_new_from_dbic( $self->_result->patron );
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

=head3 usages

Returns all usage records for this quota

=cut

sub usages {
    my ($self) = @_;
    my $usages_rs = $self->_result->patron_quota_usages;
    return Koha::Patron::Quota::Usages->_new_from_dbic($usages_rs);
}

=head3 add_usage

Creates a new usage record for this quota with the specified parameters.
Returns the new Koha::Patron::Quota::Usage object.

=cut

sub add_usage {
    my ( $self, $params ) = @_;

    # Set defaults
    $params->{patron_id}       = $self->patron_id;
    $params->{patron_quota_id} = $self->id;
    $params->{issue_id}        = undef unless exists $params->{issue_id};

    # Create usage record
    my $usage = Koha::Patron::Quota::Usage->new($params)->store;

    # Update quota used amount
    $self->add_to_quota( $params->{amount} );

    return $usage;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronQuota';
}

1;
