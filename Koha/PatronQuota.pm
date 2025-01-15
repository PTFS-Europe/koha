package Koha::PatronQuota;

use Modern::Perl;
use base qw(Koha::Object);

=head1 NAME

Koha::PatronQuota - Koha PatronQuota Object class

=head1 API

=head2 Class Methods

=head3 type

=cut

sub _type {
    return 'PatronQuota';
}


1;