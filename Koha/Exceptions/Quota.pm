package Koha::Exceptions::Quota;

use Modern::Perl;

use Koha::Exceptions;

use Exception::Class (
    'Koha::Exceptions::Quota' => {
        description => 'Base class for Quota-related exceptions',
        isa         => 'Koha::Exception',
    },
    'Koha::Exceptions::Quota::Clash' => {
        isa         => 'Koha::Exceptions::Quota',
        description => 'Thrown when a quota period overlaps with an existing one',
    },
    'Koha::Exceptions::Quota::NoAvailableQuota' => {
        isa         => 'Koha::Exceptions::Quota', 
        description => 'Thrown when no quota with sufficient availability was found',
    }
);

1;
