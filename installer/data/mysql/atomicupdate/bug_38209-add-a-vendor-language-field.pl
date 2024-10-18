use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "38209",
    description => "Add a language to the vendor table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'aqbooksellers', 'language' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE aqbooksellers
                        ADD COLUMN `language` varchar(255) NULL DEFAULT NULL
                        COMMENT 'the language for the vendor'
                        AFTER payment_method
            }
            );

            say $out "Added new column 'aqbooksellers.language'";
        }
    },
};
