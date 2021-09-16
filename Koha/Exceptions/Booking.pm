package Koha::Exceptions::Booking;

use Modern::Perl;

use Exception::Class (
    'Koha::Exceptions::Booking' => {
        description => "Something went wrong!"
    },
    'Koha::Exceptions::Booking::Clash' => {
        isa         => 'Koha::Exceptions::Booking',
        description => "Adding or updateing the booking would result in a clash"
    },
);

1;
