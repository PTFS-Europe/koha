use Modern::Perl;

return {
    bug_number  => "38489",
    description => "Move SFTP data from EDI module to FTP/SFTP table",
    up          => sub {
        my ($args)        = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( TableExists('sftp_servers') ) {
            if ( column_exists( 'vendor_edi_accounts', 'host')
            && column_exists( 'vendor_edi_accounts', 'download_port' )
            && column_exists( 'vendor_edi_accounts', 'upload_port' )
            && column_exists( 'vendor_edi_accounts', 'transport' )
            && column_exists( 'vendor_edi_accounts', 'username' )
            && column_exists( 'vendor_edi_accounts', 'password' ) )
            {
                ## copy edi vendor sftp servers to sftp_servers
                $dbh->do(
                    q{
                        INSERT IGNORE INTO `sftp_servers` (name,host,port,transport,user_name,password,download_directory,upload_directory)
                        SELECT description,host,download_port,LOWER(transport),username,password,download_directory,upload_directory
                        FROM vendor_edi_accounts
                        WHERE vendor_edi_accounts.download_port IS NOT NULL;
                    }
                );
                say $out "Copied FTP/SFTP download servers from vendor_edi_accounts table";

                $dbh->do(
                    q{
                        INSERT IGNORE INTO `sftp_servers` (name,host,port,transport,user_name,password,download_directory,upload_directory)
                        SELECT description,host,upload_port,LOWER(transport),username,password,download_directory,upload_directory
                        FROM vendor_edi_accounts
                        WHERE vendor_edi_accounts.upload_port IS NOT NULL;
                    }
                );
                say $out "Copied FTP/SFTP upload servers from vendor_edi_accounts table";

                ## add foreign keys
                unless ( column_exists( 'vendor_edi_accounts', 'download_sftp_server_id' )
                    || column_exists( 'vendor_edi_accounts', 'upload_sftp_server_id' ) )
                {
                    $dbh->do(
                        q{
                            ALTER TABLE `vendor_edi_accounts`
                                ADD COLUMN `download_sftp_server_id` int(11) DEFAULT NULL AFTER `description`,
                                ADD COLUMN `upload_sftp_server_id` int(11) DEFAULT NULL AFTER `download_sftp_server_id`;
                        }
                    );
                    say $out "Added download_sftp_server_id column in vendor_edi_accounts table";
                    say $out "Added upload_sftp_server_id column in vendor_edi_accounts table";
                }
                unless ( foreign_key_exists( 'vendor_edi_accounts', 'vfk_download_sftp_server_id' )
                    || foreign_key_exists( 'vendor_edi_accounts', 'vfk_upload_sftp_server_id' ) )
                {
                    $dbh->do(
                        q{
                            ALTER TABLE `vendor_edi_accounts`
                                ADD CONSTRAINT `vfk_download_sftp_server_id` FOREIGN KEY (`download_sftp_server_id`) REFERENCES `sftp_servers` (`id`),
                                ADD CONSTRAINT `vfk_upload_sftp_server_id` FOREIGN KEY (`upload_sftp_server_id`) REFERENCES `sftp_servers` (`id`);
                        }
                    );
                    say $out "Added vfk_download_sftp_server_id constraint in vendor_edi_accounts table";
                    say $out "Added vfk_upload_sftp_server_id constraint in vendor_edi_accounts table";
                }

                ## set matching sftp server ids in new foreign keys
                $dbh->do(
                    q{
                        UPDATE IGNORE `vendor_edi_accounts`, `sftp_servers`
                            SET vendor_edi_accounts.download_sftp_server_id = sftp_servers.id
                            WHERE vendor_edi_accounts.host = sftp_servers.host
                            AND vendor_edi_accounts.download_port = sftp_servers.port
                            AND vendor_edi_accounts.transport = sftp_servers.transport
                            AND vendor_edi_accounts.download_directory = sftp_servers.download_directory
                            AND vendor_edi_accounts.upload_directory = sftp_servers.upload_directory;
                    }
                );
                say $out "Matched sftp_server.id with vendor_edi_accounts.download_sftp_server_id";
                $dbh->do(
                    q{
                        UPDATE IGNORE `vendor_edi_accounts`, `sftp_servers`
                            SET vendor_edi_accounts.upload_sftp_server_id = sftp_servers.id
                            WHERE vendor_edi_accounts.host = sftp_servers.host
                            AND vendor_edi_accounts.upload_port = sftp_servers.port
                            AND vendor_edi_accounts.transport = sftp_servers.transport
                            AND vendor_edi_accounts.download_directory = sftp_servers.download_directory
                            AND vendor_edi_accounts.upload_directory = sftp_servers.upload_directory;
                    }
                );
                say $out "Matched sftp_server.id with vendor_edi_accounts.upload_sftp_server_id";


                ## drop useless columns from edi vendors
                $dbh->do(
                    q{
                        ALTER TABLE vendor_edi_accounts
                            DROP COLUMN `host`,
                            DROP COLUMN `username`,
                            DROP COLUMN `password`,
                            DROP COLUMN `download_port`,
                            DROP COLUMN `upload_port`,
                            DROP COLUMN `transport`;
                    }
                );
                say $out "Dropped host column in vendor_edi_accounts table";
                say $out "Dropped username column in vendor_edi_accounts table";
                say $out "Dropped password column in vendor_edi_accounts table";
                say $out "Dropped download_port column in vendor_edi_accounts table";
                say $out "Dropped upload_port column in vendor_edi_accounts table";
                say $out "Dropped transport column in vendor_edi_accounts table";
            }
        }
    },
};
