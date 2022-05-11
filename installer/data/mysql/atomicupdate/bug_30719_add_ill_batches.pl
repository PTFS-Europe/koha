use Modern::Perl;

return {
    bug_number => "30719",
    description => "Add ILL batches",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        $dbh->do(q{
            CREATE TABLE `illbatches` (
                `id` int(11) NOT NULL auto_increment, -- Batch ID
                `name` varchar(100) NOT NULL,         -- Unique name of batch
                `backend` varchar(20) NOT NULL,       -- Name of batch backend
                `borrowernumber` int(11),             -- Patron associated with batch
                `branchcode` varchar(50),             -- Branch associated with batch
                PRIMARY KEY (`id`),
                UNIQUE KEY `u_illbatches__name` (`name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        });
        $dbh->do(q{
            ALTER TABLE `illrequests`
                ADD COLUMN `batch_id` int(11) AFTER backend -- Optional ID of batch that this request belongs to
        });
        $dbh->do(q{
            ALTER TABLE `illrequests`
                ADD CONSTRAINT `illrequests_ibfk` FOREIGN KEY (`batch_id`) REFERENCES `illbatches` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
        });
        $dbh->do(q{
            ALTER TABLE `illbatches`
                ADD CONSTRAINT `illbatches_bnfk` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE
        });
        $dbh->do(q{
            ALTER TABLE `illbatches`
                ADD CONSTRAINT `illbatches_bcfk` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE SET NULL ON UPDATE CASCADE
        });
        say $out "Bug 30719: Add ILL batches completed"
    },
};
