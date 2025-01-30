use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "38924",
    description => "Add patron quota table and permissions",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('patron_quota') ) {
            $dbh->do(
                q{
                CREATE TABLE `patron_quota` (
                  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique identifier for the quota record',
                  `description` longtext NOT NULL COMMENT 'user friendly description for the quota record',
                  `patron_id` int(11) NOT NULL COMMENT 'foreign key linking to borrowers.borrowernumber',
                  `allocation` int(11) NOT NULL DEFAULT 0 COMMENT 'total quota allocation for the period',
                  `used` int(11) NOT NULL DEFAULT 0 COMMENT 'amount of allocation used for current period',
                  `start_date` date NOT NULL COMMENT 'start date of the allocation period',
                  `end_date` date NOT NULL COMMENT 'end date of the allocation period',
                  PRIMARY KEY (`id`),
                  KEY `patron_quota_ibfk_1` (`patron_id`),
                  CONSTRAINT `patron_quota_ibfk_1` FOREIGN KEY (`patron_id`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            $dbh->do(q{
                INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
                (4, 'manage_borrower_quotas', 'Manage patron quotas'),
                (4, 'view_borrower_quotas', 'View patron quotas')
            });
            
            say_success( $out, "Patron quota table and permissions created successfully" );
        } else {
            say_info( $out, "Patron quota table already exists" );
        }
    },
};
