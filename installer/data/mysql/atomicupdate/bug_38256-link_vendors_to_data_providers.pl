use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "38256",
    description => "Link vendors to data providers",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'erm_usage_data_providers', 'vendor_id' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE erm_usage_data_providers
                        ADD COLUMN `vendor_id` int(11) DEFAULT NULL
                        COMMENT 'the vendor linked to this provider'
                        AFTER service_platform
            }
            );

            say $out "Added new column 'erm_usage_data_providers.vendor'";
        }

        unless ( foreign_key_exists( 'erm_usage_data_providers', 'erm_usage_data_providers_ibfk_1' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE erm_usage_data_providers
                    ADD CONSTRAINT `erm_usage_data_providers_ibfk_1` FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
                }
                ) == 1
                && say_success(
                $out,
                "Added foreign key 'erm_usage_data_providers_ibfk_1' to column 'erm_usage_data_providers.vendor_id'"
                );
        }
    },
};
