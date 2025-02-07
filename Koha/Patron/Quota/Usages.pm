package Koha::Patron::Quota::Usages;

use base qw(Koha::Objects);
use Modern::Perl;
use Koha::Patron::Quota::Usage;

=head1 NAME

Koha::Patron::Quota::Usages - Koha Patron Quota Usages Object set class

=head1 API

=head2 Class methods

=cut

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronQuotaUsage';
}

=head3 object_class

=cut

sub koha_object_class {
    return 'Koha::Patron::Quota::Usage';
}

sub object_class {
    return 'Koha::Patron::Quota::Usage';
}

1;
