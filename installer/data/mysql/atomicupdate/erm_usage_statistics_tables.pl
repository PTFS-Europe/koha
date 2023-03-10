use Modern::Perl;

return {
    bug_number => "XXXX",
    description => "Creating the tables for ERM Usage Statistics",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        unless( TableExists( 'erm_platforms')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_platforms` (
                    `erm_platform_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `name` varchar(80) NOT NULL COMMENT 'name of the platform',
                    `description` longtext DEFAULT NULL COMMENT 'description of the platform',
                    PRIMARY KEY (`erm_platform_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_platforms";
        } else {
            say $out "erm_platforms table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_harvesters')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_harvesters` (
                    `erm_harvester_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `platform_id` int(11) DEFAULT NULL COMMENT 'foreign key to erm_platform',
                    `status` varchar(80) DEFAULT NULL COMMENT 'current status of the harvester',
                    `method` varchar(80) DEFAULT NULL COMMENT 'method of the harvester',
                    `aggregator` varchar(80) DEFAULT NULL COMMENT 'aggregator of the harvester',
                    `service_type` varchar(80) DEFAULT NULL COMMENT 'service_type of the harvester',
                    `service_url` varchar(80) DEFAULT NULL COMMENT 'service_url of the harvester',
                    `report_release` varchar(80) DEFAULT NULL COMMENT 'report_release of the harvester',
                    `begin_date` date DEFAULT NULL COMMENT 'start date of the harvester',
                    `end_date` date DEFAULT NULL COMMENT 'end date of the harvester',
                    `customer_id` varchar(50) NOT NULL COMMENT 'sushi customer id',
                    `requestor_id` varchar(50) DEFAULT NULL COMMENT 'sushi requestor id',
                    `api_key` varchar(80) DEFAULT NULL COMMENT 'sushi api key',
                    `platform` varchar(80) DEFAULT NULL COMMENT 'platform name',
                    `requestor_name` varchar(80) DEFAULT NULL COMMENT 'requestor name',
                    `requestor_email` varchar(80) DEFAULT NULL COMMENT 'requestor email',
                    `report_types` varchar(80) NOT NULL COMMENT 'report types provided by the harvester',
                    PRIMARY KEY (`erm_harvester_id`),
                    CONSTRAINT `erm_harvester_ibfk_1` FOREIGN KEY (`platform_id`) REFERENCES `erm_platforms` (`erm_platform_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_harvesters";
        } else {
            say $out "erm_harvesters table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_counter_files')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_counter_files` (
                    `erm_counter_files_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `harvester_id` int(11) DEFAULT NULL COMMENT 'foreign key to erm_harvester',
                    `type` varchar(80) DEFAULT NULL COMMENT 'type of counter file',
                    `filename` varchar(80) DEFAULT NULL COMMENT 'name of the counter file',
                    `file_content` longblob DEFAULT NULL COMMENT 'content of the counter file',
                    `date_uploaded` timestamp DEFAULT NULL DEFAULT current_timestamp() COMMENT 'counter file upload date',
                    PRIMARY KEY (`erm_counter_files_id`),
                    CONSTRAINT `erm_counter_files_ibfk_1` FOREIGN KEY (`harvester_id`) REFERENCES `erm_harvesters` (`erm_harvester_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_counter_files";
        } else {
            say $out "erm_counter_files table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_counter_logs')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_counter_logs` (
                    `erm_counter_log_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `borrowernumber` int(11) DEFAULT NULL COMMENT 'foreign key to borrowers',
                    `counter_files_id` int(11) DEFAULT NULL COMMENT 'foreign key to erm_counter_files',
                    `importdate` timestamp DEFAULT NULL DEFAULT current_timestamp() COMMENT 'counter file import date',
                    `filename` varchar(80) DEFAULT NULL COMMENT 'name of the counter file',
                    `logdetails` longtext DEFAULT NULL COMMENT 'details from the counter log',
                    PRIMARY KEY (`erm_counter_log_id`),
                    CONSTRAINT `erm_counter_log_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `erm_counter_log_ibfk_2` FOREIGN KEY (`counter_files_id`) REFERENCES `erm_counter_files` (`erm_counter_files_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_counter_logs";
        } else {
            say $out "erm_counter_logs table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_usage_titles')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_titles` (
                    `title_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `title` varchar(255) DEFAULT NULL COMMENT 'item title',
                    PRIMARY KEY (`title_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_titles";
        } else {
            say $out "erm_usage_titles table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_usage_mus')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_mus` (
                    `monthly_usage_summary_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `title_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                    `platform_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                    `year` int(4) DEFAULT NULL COMMENT 'year of usage statistics',
                    `month` int(2) DEFAULT NULL COMMENT 'month of usage statistics',
                    `usage_count` int(11) DEFAULT NULL COMMENT 'usage count for the title',
                    PRIMARY KEY (`monthly_usage_summary_id`),
                    CONSTRAINT `erm_usage_mus_ibfk_1` FOREIGN KEY (`title_id`) REFERENCES `erm_usage_titles` (`title_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `erm_usage_mus_ibfk_2` FOREIGN KEY (`platform_id`) REFERENCES `erm_platforms` (`erm_platform_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_mus";
        } else {
            say $out "erm_usage_mus table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_usage_yus')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_yus` (
                    `yearly_usage_summary_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    `title_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                    `platform_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                    `year` int(4) DEFAULT NULL COMMENT 'year of usage statistics',
                    `totalcount` int(11) DEFAULT NULL COMMENT 'usage count for the title',
                    `ytd_html_count` int(11) DEFAULT NULL COMMENT 'full text html request count for the title',
                    `ytd_pdf_count` int(11) DEFAULT NULL COMMENT 'full text pdf request count for the title',
                    PRIMARY KEY (`yearly_usage_summary_id`),
                    CONSTRAINT `erm_usage_yus_ibfk_1` FOREIGN KEY (`title_id`) REFERENCES `erm_usage_titles` (`title_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                    CONSTRAINT `erm_usage_yus_ibfk_2` FOREIGN KEY (`platform_id`) REFERENCES `erm_platforms` (`erm_platform_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_yus";
        } else {
            say $out "erm_usage_yus table already exists - skipping to next table";
        }
        
        $dbh->do(q{
            INSERT IGNORE INTO authorised_value_categories (category_name, is_system)
            VALUES
                ('ERM_REPORT_TYPES', 1);
            });
        $dbh->do(q{
            INSERT IGNORE INTO authorised_values (category, authorised_value, lib)
            VALUES
                ('ERM_REPORT_TYPES', 'PR', 'PR - Platform master report'),
                ('ERM_REPORT_TYPES', 'PR_P1', 'PR_P1 - Platform usage'),
                ('ERM_REPORT_TYPES', 'DR', 'DR - Database master report'),
                ('ERM_REPORT_TYPES', 'DR_D1', 'DR_D1 - Database search and item usage'),
                ('ERM_REPORT_TYPES', 'DR_D2', 'DR_D2 - Database access denied'),
                ('ERM_REPORT_TYPES', 'TR', 'TR - Title master report'),
                ('ERM_REPORT_TYPES', 'TR_B1', 'TR_B1 - Book requests (excluding OA_Gold)'),
                ('ERM_REPORT_TYPES', 'TR_B2', 'TR_B2 - Book access denied'),
                ('ERM_REPORT_TYPES', 'TR_B3', 'TR_B3 - Book usage by access type'),
                ('ERM_REPORT_TYPES', 'TR_J1', 'TR_J1 - Journal requests (excluding OA_Gold)'),
                ('ERM_REPORT_TYPES', 'TR_J2', 'TR_J2 - Journal access denied'),
                ('ERM_REPORT_TYPES', 'TR_J3', 'TR_J3 - Journal usage by access type'),
                ('ERM_REPORT_TYPES', 'TR_J4', 'TR_J4 - Journal requests by YOP(excluding OA_Gold)'),
                ('ERM_REPORT_TYPES', 'IR', 'IR - Item master report'),
                ('ERM_REPORT_TYPES', 'IR_A1', 'IR_A1 - Journal article requests'),
                ('ERM_REPORT_TYPES', 'IR_M1', 'IR_M1 - Multimedia item requests');
        });
    },
};
