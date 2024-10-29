use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "38290",
    description => "Add library group filtering",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'aqbooksellers', 'lib_group_visibility' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE aqbooksellers
                        ADD COLUMN `lib_group_visibility` varchar(255) NULL DEFAULT NULL
                        COMMENT 'the library groups the vendor is visible to'
                        AFTER language
            }
            );

            say $out "Added new column 'aqbooksellers.lib_group_visibility'";
        }

        if ( !column_exists( 'library_groups', 'ft_acquisitions' ) ) {
            $dbh->do(
                "ALTER TABLE `library_groups` ADD COLUMN `ft_acquisitions` tinyint(1) NOT NULL DEFAULT 0 AFTER `ft_local_float_group`"
            );
        }

    },
};
