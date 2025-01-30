package Koha::Patron::Quota::Usages;

use Modern::Perl;

use base qw(Koha::Objects);

=head1 NAME

Koha::Patron::Quota::Usages - Koha Patron Quota Usages Object set class

=head1 API

=head2 Class methods

=cut

sub _type {
    return 'PatronQuotaUsage';
}

sub object_class {
    return 'Koha::Patron::Quota::Usage';
}

=head2 Internal methods

=head3 _type

=head3 object_class

=cut

1;
