use Modern::Perl;

return {
    bug_number  => "35625",
    description => "Add is_system field to additional_fields table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'additional_fields', 'is_system' ) ) {
            $dbh->do(
                "ALTER TABLE `additional_fields` ADD COLUMN `is_system` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'is this field required for system operation' AFTER `tablename`"
            );
            say $out "Added column 'additional_fields.is_system'";
        }
    },
};
