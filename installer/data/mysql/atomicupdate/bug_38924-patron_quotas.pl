use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "38924",
    description => "Add patron quota and quota usage tables, add permissions and sysprefs for quotas",
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
            say_success( $out, "Patron quota table created successfully" );
        } else {
            say_info( $out, "Patron quota table already exists" );
        }
        unless ( TableExists('patron_quota_usage') ) {
            $dbh->do(
                q{
                CREATE TABLE `patron_quota_usage` (
                  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique identifier for quota usage record',
                  `patron_quota_id` int(11) NOT NULL COMMENT 'foreign key linking to patron_quota.id',
                  `issue_id` int(11) DEFAULT NULL COMMENT 'linking to issues.issue_id or old_issues.issue_id',
                  `patron_id` int(11) NOT NULL COMMENT 'foreign key linking to borrowers.borrowernumber',
                  `type` enum('ISSUE','RENEW') NOT NULL COMMENT 'The type of usage this is',
                  `creation_date` timestamp NOT NULL DEFAULT current_timestamp() COMMENT 'the timestamp for when a usage was recorded',
                  PRIMARY KEY (`id`),
                  KEY `patron_quota_usage_ibfk_1` (`patron_quota_id`),
                  KEY `patron_quota_usage_ibfk_2` (`patron_id`),
                  KEY `patron_quota_usage_issue_id` (`issue_id`),
                  CONSTRAINT `patron_quota_usage_ibfk_1` FOREIGN KEY (`patron_quota_id`) REFERENCES `patron_quota` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `patron_quota_usage_ibfk_2` FOREIGN KEY (`patron_id`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );
            $dbh->do(
                q{
                INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
                (4, 'manage_borrower_quotas', 'Manage patron quotas'),
                (4, 'view_borrower_quotas', 'View patron quotas')
            }
            );
            $dbh->do(
                q{
                INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
                VALUES 
                ('AllowQuotaOverride', '0', NULL, 'Allow staff to override and check out items to patrons who have exceeded their quota limit', 'YesNo'),
                ('UseGuarantorQuota', '0', NULL, 'Use guarantor quota instead of guarantee quota when checking out items', 'YesNo')
            }
            );
            say_success( $out, "Patron quota usage table, permissions and syspref created successfully" );
        } else {
            say_info( $out, "Patron quota usage table already exists" );
        }
    },
};
