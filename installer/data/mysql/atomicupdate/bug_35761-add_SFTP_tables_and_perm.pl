use Modern::Perl;

return {
    bug_number  => "35761",
    description => "Add new table and permission for generalised SFTP",
    up          => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(q{
            INSERT IGNORE INTO permissions (module_bit, code, description)
            VALUES (3, 'manage_sftp_servers', 'Manage FTP/SFTP servers configuration');
        });
        say $out "Added new manage_sftp_servers permission";

        unless(TableExists('sftp_servers')) {
            $dbh->do(q{
                CREATE TABLE `sftp_servers` (
                  `id` int(11) NOT NULL AUTO_INCREMENT,
                  `name` varchar(80) NOT NULL,
                  `host` varchar(80) NOT NULL DEFAULT 'localhost',
                  `port` int(11) NOT NULL DEFAULT 22,
                  `transport` enum('ftp','sftp','file') NOT NULL DEFAULT 'sftp',
                  `passiv` tinyint(1) NOT NULL DEFAULT 1,
                  `user_name` varchar(80) DEFAULT NULL,
                  `password` varchar(80) DEFAULT NULL,
                  `key_file` varchar(4096) DEFAULT NULL,
                  `auth_mode` enum('password','key_file','noauth') NOT NULL DEFAULT 'password',
                  `debug` tinyint(1) NOT NULL DEFAULT 0,
                  PRIMARY KEY (`id`),
                  KEY `host_idx` (`host`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });
            say $out "Added new sftp_servers table";
        }

        unless(!TableExists('sftp_servers')) { ## be sure the step above worked
            unless(!column_exists('vendor_edi_accounts', 'host')) { ## be sure host column exists
                # Copy ftp/sftp data to sftp_servers
                $dbh->do(q{
                    INSERT IGNORE INTO `sftp_servers` (id,name,host,port,transport,user_name,password)
                    SELECT id,description,host,upload_port,LOWER(transport),username,password
                    FROM vendor_edi_accounts;
                });
                say $out "Copied FTP/SFTP servers from vendor_edi_accounts table";

                # Add new column
                $dbh->do(q{
                    ALTER TABLE `vendor_edi_accounts`
                        ADD COLUMN `sftp_server_id` int(11) DEFAULT NULL
                        AFTER `description`;
                });
                say $out "Added sftp_server_id column in vendor_edi_accounts table";

                # Add new constraint
                $dbh->do(q{
                    ALTER TABLE `vendor_edi_accounts`
                        ADD CONSTRAINT `vfk_sftp_server_id` FOREIGN KEY (`sftp_server_id`) REFERENCES `sftp_servers` (`id`);
                });
                say $out "Added vfk_sftp_server_id constraint in vendor_edi_accounts table";

                # Drop old column
                $dbh->do(q{
                    ALTER TABLE vendor_edi_accounts
                        DROP COLUMN `host`,
                        DROP COLUMN `username`,
                        DROP COLUMN `password`,
                        DROP COLUMN `upload_port`,
                        DROP COLUMN `download_port`,
                        DROP COLUMN `transport`;
                });
                say $out "Dropped host column in vendor_edi_accounts table";
                say $out "Dropped username column in vendor_edi_accounts table";
                say $out "Dropped password column in vendor_edi_accounts table";
                say $out "Dropped upload_port column in vendor_edi_accounts table";
                say $out "Dropped download_port column in vendor_edi_accounts table";
                say $out "Dropped transport column in vendor_edi_accounts table";
            }
        }
    },
};
