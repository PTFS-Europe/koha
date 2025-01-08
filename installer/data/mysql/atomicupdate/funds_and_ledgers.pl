use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "tbc",
    description => "Funds and ledgers tables",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( TableExists('fiscal_period') ) {
            $dbh->do(
                q{
                CREATE TABLE `fiscal_period` (
                `fiscal_period_id` INT(11) NOT NULL AUTO_INCREMENT,
                `description` longtext DEFAULT '' COMMENT 'description for the fiscal period',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the fiscal period',
                `start_date` date DEFAULT NULL COMMENT 'start date of the event',
                `end_date` date DEFAULT NULL COMMENT 'end date of the event',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the fiscal period',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fiscal period currently active',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fiscal period',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fiscal period',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the fiscal period is visible to',
                PRIMARY KEY (`fiscal_period_id`),
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fiscal_period'" );
        } else {
            say_info( $out, "Table 'fiscal_period' already exists" );
        }

        unless ( TableExists('ledgers') ) {
            $dbh->do(
                q{
                CREATE TABLE `ledgers` (
                `ledger_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the ledger applies to',
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the ledger',
                `description` longtext DEFAULT '' COMMENT 'description for the ledger',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the ledger',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the ledger for use with external accounting systems',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the ledger',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the ledger currently active',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the ledger',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the ledger',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the ledger is visible to',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the ledger',
                `over_spend_allowed` TINYINT(1) DEFAULT '1' COMMENT 'is an overspend allowed on the ledger',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_limit_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overspend',
                `os_warning_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a warning for overspend',
                `os_limit_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a block on the ledger for overspend',
                PRIMARY KEY (`ledger_id`),
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'ledgers'" );
        } else {
            say_info( $out, "Table 'ledgers' already exists" );
        }

        unless ( TableExists('fund_group') ) {
            $dbh->do(
                q{
                CREATE TABLE `fund_group` (
                `fund_group_id` INT(11) NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the fund group',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund allocation',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the fund allocation is visible to',
                PRIMARY KEY (`fund_group_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fund_group'" );
        } else {
            say_info( $out, "Table 'fund_group' already exists" );
        }

        unless ( TableExists('funds') ) {
            $dbh->do(
                q{
                CREATE TABLE `funds` (
                `fund_id` INT(11) NOT NULL AUTO_INCREMENT,
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the fund applies to',
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the fund applies to',
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the fund',
                `description` longtext DEFAULT '' COMMENT 'description for the fund',
                `fund_type` VARCHAR(255) DEFAULT NULL COMMENT 'type for the fund',
                `fund_group_id` INT(11) DEFAULT NULL COMMENT 'group for the fund',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the fund',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the fund for use with external accounting systems',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the fund currently active',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fund',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the fund',
                `over_spend_allowed` TINYINT(1) DEFAULT '1' COMMENT 'is an overspend allowed on the fund',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_limit_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overspend',
                `os_warning_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a warning for overspend',
                `os_limit_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a block on the fund for overspend',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fund',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the fund is visible to',
                PRIMARY KEY (`fund_id`),
                FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fund_group_id`) REFERENCES `fund_group` (`fund_group_id`) ON DELETE SET NULL ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'funds'" );
        } else {
            say_info( $out, "Table 'funds' already exists" );
        }

        unless ( TableExists('sub_funds') ) {
            $dbh->do(
                q{
                CREATE TABLE `sub_funds` (
                `sub_fund_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_id` INT(11) DEFAULT NULL COMMENT 'parent fund for the sub fund',
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the sub_fund applies to',
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the sub_fund applies to',
                `name` VARCHAR(255) DEFAULT NULL COMMENT 'name for the sub_fund',
                `description` longtext DEFAULT '' COMMENT 'description for the sub_fund',
                `sub_fund_type` VARCHAR(255) DEFAULT NULL COMMENT 'type for the sub_fund',
                `code` VARCHAR(255) DEFAULT NULL COMMENT 'code for the sub_fund',
                `external_id` VARCHAR(255) DEFAULT NULL COMMENT 'external id for the sub_fund for use with external accounting systems',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the sub_fund',
                `status` TINYINT(1) DEFAULT '1' COMMENT 'is the sub_fund currently active',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the sub_fund',
                `spend_limit` decimal(28,2) DEFAULT 0.00 COMMENT 'spend limit for the sub_fund',
                `over_spend_allowed` TINYINT(1) DEFAULT '1' COMMENT 'is an overspend allowed on the sub_fund',
                `oe_warning_percent` decimal(5,4) DEFAULT 0.0000 COMMENT 'percentage limit for overencumbrance',
                `oe_limit_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'limit for overspend',
                `os_warning_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a warning for overspend',
                `os_limit_sum` decimal(28,2) DEFAULT 0.00 COMMENT 'amount to trigger a block on the sub_fund for overspend',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the sub_fund',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the sub_fund is visible to',
                PRIMARY KEY (`sub_fund_id`),
                FOREIGN KEY (`fund_id`) REFERENCES `funds` (`fund_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'sub_funds'" );
        } else {
            say_info( $out, "Table 'sub_funds' already exists" );
        }

        unless ( TableExists('fund_allocation') ) {
            $dbh->do(
                q{
                CREATE TABLE `fund_allocation` (
                `fund_allocation_id` INT(11) NOT NULL AUTO_INCREMENT,
                `fund_id` INT(11) DEFAULT NULL COMMENT 'fund the fund allocation applies to',
                `sub_fund_id` INT(11) DEFAULT NULL COMMENT 'sub fund the fund allocation applies to',
                `ledger_id` INT(11) DEFAULT NULL COMMENT 'ledger the fund allocation applies to',
                `fiscal_period_id` INT(11) DEFAULT NULL COMMENT 'fiscal period the fund allocation applies to',
                `allocation_amount` decimal(28,2) DEFAULT 0.00 COMMENT 'amount for the allocation',
                `reference` VARCHAR(255) DEFAULT NULL COMMENT 'allocation reference',
                `note` longtext DEFAULT '' COMMENT 'any notes associated to the allocation',
                `currency` VARCHAR(10) DEFAULT NULL COMMENT 'currency of the fund allocation',
                `owner_id` INT(11) DEFAULT NULL COMMENT 'owner of the fund allocation',
                `type` enum('encumbered','spent', 'transfer', 'credit') DEFAULT NULL COMMENT 'type of the fund allocation',
                `is_transfer` TINYINT(1) DEFAULT '0' COMMENT 'is the fund allocation a transfer to/from another fund',
                `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp() COMMENT 'time of the last update to the fund allocation',
                `lib_group_visibility` VARCHAR(255) DEFAULT NULL COMMENT 'library groups the fund allocation is visible to',
                PRIMARY KEY (`fund_allocation_id`),
                FOREIGN KEY (`sub_fund_id`) REFERENCES `sub_funds` (`sub_fund_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fund_id`) REFERENCES `funds` (`fund_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`ledger_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`fiscal_period_id`) REFERENCES `fiscal_period` (`fiscal_period_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (`owner_id`) REFERENCES `borrowers` (`borrowernumber`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            }
            );

            say_success( $out, "Added new table 'fund_allocation'" );
        } else {
            say_info( $out, "Table 'fund_allocation' already exists" );
        }

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_value_categories(  category_name, is_system  ) VALUES
                ('ACQUIRE_FUND_TYPE', 1),
                ('ACQUIRE_FUND_GROUP', 1);
                }
        );
        say_success( $out, "Added new categories 'ACQUIRE_FUND_TYPE' and 'ACQUIRE_FUND_GROUP'" );

        $dbh->do(
            q{
                INSERT IGNORE INTO authorised_values(  category, authorised_value, lib  ) VALUES
                ('ACQUIRE_FUND_TYPE', "PRINT", "Print materials"),
                ('ACQUIRE_FUND_TYPE', "ELECTRONIC", "Electronic materials"),
                ('ACQUIRE_FUND_TYPE', "SUBSCRIPTION", "Subscription materials"),
                ('ACQUIRE_FUND_TYPE', "MISC", "Miscellaneous expenses"),
                ('ACQUIRE_FUND_GROUP', "BUSINESS", "Business"),
                ('ACQUIRE_FUND_GROUP', "ACADEMIC", "Academic"),
                ('ACQUIRE_FUND_GROUP', "MISC", "Misc");
                }
        );
        say_success( $out, "Added new authorised values to those categories" );

    },
};
