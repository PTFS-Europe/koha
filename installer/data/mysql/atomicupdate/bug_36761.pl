use Modern::Perl;

return {
    bug_number  => "36761",
    description => "Add ability to specify patron attribute as a boolean",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        unless ( column_exists( 'borrower_attribute_types', 'is_boolean' ) ) {
            $dbh->do(
                q{ALTER TABLE borrower_attribute_types ADD COLUMN `is_boolean` tinyint(1) NOT NULL default 0 AFTER `unique_id`}

            );
            say $out "Added column 'borrower_attribute_types.is_boolean'";
        }
    },
};
