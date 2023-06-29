use Modern::Perl;

return {
    bug_number => "30719",
    description => "Add ILL batches",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        $dbh->do(q{
            CREATE TABLE IF NOT EXISTS `illbatches` (
                `id` int(11) NOT NULL auto_increment COMMENT "Batch ID",
                `name` varchar(100) NOT NULL COMMENT "Unique name of batch",
                `backend` varchar(20) NOT NULL COMMENT "Name of batch backend",
                `borrowernumber` int(11) COMMENT "Patron associated with batch",
                `branchcode` varchar(50) COMMENT "Branch associated with batch",
                `statuscode` varchar(20) COMMENT "Status of batch",
                PRIMARY KEY (`id`),
                UNIQUE KEY `u_illbatches__name` (`name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        });
        $dbh->do(q{
            CREATE TABLE IF NOT EXISTS `illbatch_statuses` (
                `id` int(11) NOT NULL auto_increment COMMENT "Status ID",
                `name` varchar(100) NOT NULL COMMENT "Name of status",
                `code` varchar(20) NOT NULL COMMENT "Unique, immutable code for status",
                `is_system` int(1) COMMENT "Is this status required for system operation",
                PRIMARY KEY (`id`),
                UNIQUE KEY `u_illbatchstatuses__code` (`code`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        });
        unless( column_exists('illrequests', 'batch_id') ) {
            $dbh->do(q{
                ALTER TABLE `illrequests`
                    ADD COLUMN `batch_id` int(11) AFTER backend -- Optional ID of batch that this request belongs to
            });
        }

        unless ( foreign_key_exists( 'illrequests', 'illrequests_ibfk' ) ){
            $dbh->do(q{
                ALTER TABLE `illrequests`
                    ADD CONSTRAINT `illrequests_ibfk` FOREIGN KEY (`batch_id`) REFERENCES `illbatches` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
            });
        }

        unless ( foreign_key_exists( 'illbatches', 'illbatches_bnfk' ) ){
            $dbh->do(q{
                ALTER TABLE `illbatches`
                    ADD CONSTRAINT `illbatches_bnfk` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
            });
        }

        unless ( foreign_key_exists( 'illbatches', 'illbatches_bcfk' ) ){
            $dbh->do(q{
                ALTER TABLE `illbatches`
                    ADD CONSTRAINT `illbatches_bcfk` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE SET NULL ON UPDATE CASCADE
            });
        }

        unless ( foreign_key_exists( 'illbatches', 'illbatches_sfk' ) ){
            $dbh->do(q{
                ALTER TABLE `illbatches`
                    ADD CONSTRAINT `illbatches_sfk` FOREIGN KEY (`statuscode`) REFERENCES `illbatch_statuses` (`code`) ON DELETE SET NULL ON UPDATE CASCADE
            });
        }

        say $out "Bug 30719: Add ILL batches completed"
    },
};
