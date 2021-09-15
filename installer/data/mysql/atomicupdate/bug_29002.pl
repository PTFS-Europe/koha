use Modern::Perl;

return {
    bug_number => "29002",
    description => "Add bookings table",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{
            CREATE TABLE `bookings` (
              `booking_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
              `borrowernumber` int(11) NOT NULL DEFAULT 0 COMMENT 'foreign key from the borrowers table defining which patron this booking is for',
              `biblionumber` int(11) NOT NULL DEFAULT 0 COMMENT 'foreign key from the biblio table defining which bib record this booking is on',
              `itemnumber` int(11) DEFAULT NULL COMMENT 'foreign key from the items table defining the specific item the patron has placed a booking for',
              `start_date` datetime DEFAULT NULL COMMENT 'the start date of the booking',
              `end_date` datetime DEFAULT NULL COMMENT 'the end date of the booking',
            PRIMARY KEY (`booking_id`),
            KEY `borrowernumber` (`borrowernumber`),
            KEY `biblionumber` (`biblionumber`),
            KEY `itemnumber` (`itemnumber`),
            CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        });
    },
}
