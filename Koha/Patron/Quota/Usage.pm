package Koha::Patron::Quota::Usage;

use Modern::Perl;

use base qw(Koha::Object);

=head1 NAME

Koha::Patron::Quota::Usage - Koha Patron Quota Usage Object class

=head1 API

=head2 Class methods

=cut

sub _type {
    return 'PatronQuotaUsage';
}

=head2 Internal methods

=head3 _type

=cut

1;
