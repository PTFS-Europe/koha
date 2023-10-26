use Modern::Perl;

return {
    bug_number => "XXXX",
    description => "Creating the tables for ERM Usage Statistics",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        unless( TableExists( 'erm_usage_data_providers')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_data_providers` (
                `erm_usage_data_provider_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `name` varchar(80) NOT NULL COMMENT 'name of the data provider',
                `description` longtext DEFAULT NULL COMMENT 'description of the data provider',
                `active` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'current status of the harvester - active/inactive',
                `method` varchar(80) DEFAULT NULL COMMENT 'method of the harvester',
                `aggregator` varchar(80) DEFAULT NULL COMMENT 'aggregator of the harvester',
                `service_type` varchar(80) DEFAULT NULL COMMENT 'service_type of the harvester',
                `service_url` varchar(80) DEFAULT NULL COMMENT 'service_url of the harvester',
                `report_release` varchar(80) DEFAULT NULL COMMENT 'report_release of the harvester',
                `customer_id` varchar(50) DEFAULT NULL COMMENT 'sushi customer id',
                `requestor_id` varchar(50) DEFAULT NULL COMMENT 'sushi requestor id',
                `api_key` varchar(80) DEFAULT NULL COMMENT 'sushi api key',
                `requestor_name` varchar(80) DEFAULT NULL COMMENT 'requestor name',
                `requestor_email` varchar(80) DEFAULT NULL COMMENT 'requestor email',
                `report_types` varchar(255) DEFAULT NULL COMMENT 'report types provided by the harvester',
                PRIMARY KEY (`erm_usage_data_provider_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_data_providers";
        } else {
            say $out "erm_usage_data_providers table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_counter_files')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_counter_files` (
                `erm_counter_files_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `usage_data_provider_id` int(11) DEFAULT NULL COMMENT 'foreign key to erm_usage_data_providers',
                `type` varchar(80) DEFAULT NULL COMMENT 'type of counter file',
                `filename` varchar(80) DEFAULT NULL COMMENT 'name of the counter file',
                `file_content` longblob DEFAULT NULL COMMENT 'content of the counter file',
                `date_uploaded` timestamp DEFAULT NULL DEFAULT current_timestamp() COMMENT 'counter file upload date',
                PRIMARY KEY (`erm_counter_files_id`),
                CONSTRAINT `erm_counter_files_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
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
                `usage_data_provider_id` int(11) NOT NULL COMMENT 'platform the title is harvested by',
                `title_doi` varchar(24) DEFAULT NULL COMMENT 'DOI number for the title',
                `print_issn` varchar(24) DEFAULT NULL COMMENT 'Print ISSN number for the title',
                `online_issn` varchar(24) DEFAULT NULL COMMENT 'Online ISSN number for the title',
                `title_uri` varchar(24) DEFAULT NULL COMMENT 'URI number for the title',
                `publisher` varchar(255) DEFAULT NULL COMMENT 'Publisher for the title',
                `publisher_id` varchar(24) DEFAULT NULL COMMENT 'Publisher ID for the title',
                `yop` varchar(24) DEFAULT NULL COMMENT 'year of publication of the title',
                `isbn` varchar(24) DEFAULT NULL COMMENT 'ISBN of the title',
                PRIMARY KEY (`title_id`),
                CONSTRAINT `erm_usage_titles_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_titles";
        } else {
            say $out "erm_usage_titles table already exists - skipping to next table";
        }

        unless ( TableExists('erm_usage_platforms') ) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_platforms` (
                `platform_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `platform` varchar(255) DEFAULT NULL COMMENT 'item title',
                `usage_data_provider_id` int(11) NOT NULL COMMENT 'data provider the platform is harvested by',
                PRIMARY KEY (`platform_id`),
                CONSTRAINT `erm_usage_platforms_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );

            say $out "Added new table erm_usage_platforms";
        } else {
            say $out "erm_usage_platforms table already exists - skipping to next table";
        }

        unless ( TableExists('erm_usage_databases') ) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_databases` (
                `database_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `database` varchar(255) DEFAULT NULL COMMENT 'item title',
                `platform` varchar(255) DEFAULT NULL COMMENT 'database platform',
                `publisher` varchar(255) DEFAULT NULL COMMENT 'Publisher for the database',
                `publisher_id` varchar(24) DEFAULT NULL COMMENT 'Publisher ID for the database',
                `usage_data_provider_id` int(11) NOT NULL COMMENT 'data provider the database is harvested by',
                PRIMARY KEY (`database_id`),
                CONSTRAINT `erm_usage_databases_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );

            say $out "Added new table erm_usage_databases";
        } else {
            say $out "erm_usage_databases table already exists - skipping to next table";
        }

        unless ( TableExists('erm_usage_items') ) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_items` (
                `item_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `item` varchar(500) DEFAULT NULL COMMENT 'item title',
                `platform` varchar(255) DEFAULT NULL COMMENT 'item platform',
                `publisher` varchar(255) DEFAULT NULL COMMENT 'Publisher for the item',
                `usage_data_provider_id` int(11) NOT NULL COMMENT 'data provider the database is harvested by',
                PRIMARY KEY (`item_id`),
                CONSTRAINT `erm_usage_items_ibfk_1` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );

            say $out "Added new table erm_usage_items";
        } else {
            say $out "erm_usage_items table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_usage_mus')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_usage_mus` (
                `monthly_usage_summary_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `title_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                `platform_id` int(11) DEFAULT NULL COMMENT 'platform id number',
                `database_id` int(11) DEFAULT NULL COMMENT 'database id number',
                `item_id` int(11) DEFAULT NULL COMMENT 'item id number',
                `usage_data_provider_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                `year` int(4) DEFAULT NULL COMMENT 'year of usage statistics',
                `month` int(2) DEFAULT NULL COMMENT 'month of usage statistics',
                `usage_count` int(11) DEFAULT NULL COMMENT 'usage count for the title',
                `metric_type` varchar(50) DEFAULT NULL COMMENT 'metric type for the usage statistic',
                `access_type` varchar(50) DEFAULT NULL COMMENT 'access type for the usage statistic',
                `report_type` varchar(50) DEFAULT NULL COMMENT 'report type for the usage statistic',
                PRIMARY KEY (`monthly_usage_summary_id`),
                CONSTRAINT `erm_usage_mus_ibfk_1` FOREIGN KEY (`title_id`) REFERENCES `erm_usage_titles` (`title_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_mus_ibfk_2` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_mus_ibfk_3` FOREIGN KEY (`platform_id`) REFERENCES `erm_usage_platforms` (`platform_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_mus_ibfk_4` FOREIGN KEY (`database_id`) REFERENCES `erm_usage_databases` (`database_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_mus_ibfk_5` FOREIGN KEY (`item_id`) REFERENCES `erm_usage_items` (`item_id`) ON DELETE CASCADE ON UPDATE CASCADE
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
                `platform_id` int(11) DEFAULT NULL COMMENT 'platform id number',
                `database_id` int(11) DEFAULT NULL COMMENT 'database id number',
                `item_id` int(11) DEFAULT NULL COMMENT 'item id number',
                `usage_data_provider_id` int(11) DEFAULT NULL COMMENT 'item title id number',
                `year` int(4) DEFAULT NULL COMMENT 'year of usage statistics',
                `totalcount` int(11) DEFAULT NULL COMMENT 'usage count for the title',
                `metric_type` varchar(50) DEFAULT NULL COMMENT 'metric type for the usage statistic',
                `access_type` varchar(50) DEFAULT NULL COMMENT 'access type for the usage statistic',
                `report_type` varchar(50) DEFAULT NULL COMMENT 'report type for the usage statistic',
                PRIMARY KEY (`yearly_usage_summary_id`),
                CONSTRAINT `erm_usage_yus_ibfk_1` FOREIGN KEY (`title_id`) REFERENCES `erm_usage_titles` (`title_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_yus_ibfk_2` FOREIGN KEY (`usage_data_provider_id`) REFERENCES `erm_usage_data_providers` (`erm_usage_data_provider_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_yus_ibfk_3` FOREIGN KEY (`platform_id`) REFERENCES `erm_usage_platforms` (`platform_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_yus_ibfk_4` FOREIGN KEY (`database_id`) REFERENCES `erm_usage_databases` (`database_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `erm_usage_yus_ibfk_5` FOREIGN KEY (`item_id`) REFERENCES `erm_usage_items` (`item_id`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_usage_yus";
        } else {
            say $out "erm_usage_yus table already exists - skipping to next table";
        }

        unless( TableExists( 'erm_default_usage_reports')) {
            $dbh->do(
                q{
                CREATE TABLE `erm_default_usage_reports` (
                `erm_default_usage_report_id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                `report_name` varchar(50) DEFAULT NULL COMMENT 'name of the default report',
                `report_url_params` longtext DEFAULT NULL COMMENT 'url params for the default report',
                PRIMARY KEY (`erm_default_usage_report_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                }
            );
            
            say $out "Added new table erm_default_usage_reports";
        } else {
            say $out "erm_default_usage_reports table already exists - skipping to next table";
        }
        
        $dbh->do(q{
            INSERT IGNORE INTO authorised_value_categories (category_name, is_system)
            VALUES
                ('ERM_REPORT_TYPES', 1),
                ('ERM_PLATFORM_REPORTS_METRICS', 1),
                ('ERM_DATABASE_REPORTS_METRICS', 1),
                ('ERM_TITLE_REPORTS_METRICS', 1),
                ('ERM_ITEM_REPORTS_METRICS', 1);
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
                ('ERM_REPORT_TYPES', 'IR_M1', 'IR_M1 - Multimedia item requests'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Searches_Platform', 'Searches platform'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Total_Item_Investigations', 'Total item investigations'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Total_Item_Requests', 'Total item requests'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Unique_Item_Investigations', 'Unique item investigations'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Unique_Item_Requests', 'Unique item requests'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Unique_Title_Investigations', 'Unique title investigations'),
                ('ERM_PLATFORM_REPORTS_METRICS', 'Unique_Title_Requests', 'Unique title requests'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Searches_Automated', 'Searches automated'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Searches_Federated', 'Searches federated'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Searches_Regular', 'Searches regular'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Total_Item_Investigations', 'Total item investigations'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Total_Item_Requests', 'Total item requests'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Unique_Item_Investigations', 'Unique item investigations'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Unique_Item_Requests', 'Unique item requests'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Unique_Title_Investigations', 'Unique title investigations'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Unique_Title_Requests', 'Unique title requests'),
                ('ERM_DATABASE_REPORTS_METRICS', 'Limit_Exceeded', 'Limit exceeded'),
                ('ERM_DATABASE_REPORTS_METRICS', 'No_License', 'No license'),
                ('ERM_TITLE_REPORTS_METRICS', 'Total_Item_Investigations', 'Total item investigations'),
                ('ERM_TITLE_REPORTS_METRICS', 'Total_Item_Requests', 'Total item requests'),
                ('ERM_TITLE_REPORTS_METRICS', 'Unique_Item_Investigations', 'Unique item investigations'),
                ('ERM_TITLE_REPORTS_METRICS', 'Unique_Item_Requests', 'Unique item requests'),
                ('ERM_TITLE_REPORTS_METRICS', 'Unique_Title_Investigations', 'Unique title investigations'),
                ('ERM_TITLE_REPORTS_METRICS', 'Unique_Title_Requests', 'Unique title requests'),
                ('ERM_TITLE_REPORTS_METRICS', 'Limit_Exceeded', 'Limit exceeded'),
                ('ERM_TITLE_REPORTS_METRICS', 'No_License', 'No license'),
                ('ERM_ITEM_REPORTS_METRICS', 'Total_Item_Investigations', 'Total item investigations'),
                ('ERM_ITEM_REPORTS_METRICS', 'Total_Item_Requests', 'Total item requests'),
                ('ERM_ITEM_REPORTS_METRICS', 'Unique_Item_Investigations', 'Unique item investigations'),
                ('ERM_ITEM_REPORTS_METRICS', 'Unique_Item_Requests', 'Unique item requests'),
                ('ERM_ITEM_REPORTS_METRICS', 'Limit_Exceeded', 'Limit exceeded'),
                ('ERM_ITEM_REPORTS_METRICS', 'No_License', 'No license');
        });
    },
};
