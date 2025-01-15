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
}
}
}

1;