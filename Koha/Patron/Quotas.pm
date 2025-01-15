=head3 get_patron_quota

Returns the active quota for a given patron

=cut

sub get_patron_quota {
    my ( $self, $patron_id ) = @_;

    return $self->search(
        {
            patron_id  => $patron_id,
            start_date => { '<=' => \'CURRENT_DATE' },
            end_date   => { '>=' => \'CURRENT_DATE' },
        }
    )->single;
}
