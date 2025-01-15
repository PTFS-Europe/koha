use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "patronquotas",
    description => "Add patron quota table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('patron_quota') ) 
        {
            $dbh->do(q{
                CREATE TABLE `patron_quota` (
                    `quota_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique identifier for the quota record',
                    `patron_id` int(11) NOT NULL COMMENT 'foreign key linking to borrowers.borrowernumber',
                    `quota_total` int(11) NOT NULL DEFAULT 0 COMMENT 'total quota allocation for the period',
                    `quota_used` int(11) NOT NULL DEFAULT 0 COMMENT 'units used within the current period',
                    `period_start` date NOT NULL COMMENT 'start date of the allocation period',
                    `period_end` date NOT NULL COMMENT 'end date of the allocation period',
                    PRIMARY KEY (`quota_id`),
                    KEY `patron_quota_ibfk_1` (`patron_id`),
                    CONSTRAINT `patron_quota_ibfk_1` FOREIGN KEY (`patron_id`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });
            say_success( $out, "Patron quota table created successfully" );
        } else {
            say_info( $out, "Patron quota table already exists" );
        }
    },
};