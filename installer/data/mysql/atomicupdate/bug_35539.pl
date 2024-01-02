use Modern::Perl;

use Term::ANSIColor qw(:constants);

return {
    bug_number  => "35539",
    description => "Remove unused columns from 'categories' table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( column_exists( 'categories', 'bulk' ) ) {
            my ($bulkdata) = $dbh->selectrow_array(
                q|
                SELECT bulk FROM categories;
            |
            );
            if ($bulkdata) {
                say $out YELLOW,
                    "Data was found in 'bulk' column in 'categories' table. Please remove this data and run the update again.";
            } else {
                $dbh->do("ALTER TABLE categories DROP COLUMN bulk");
                say $out "Removed 'bulk' column from 'categories' table";
            }
        }

        if ( column_exists( 'categories', 'finetype' ) ) {
            my ($bulkdata) = $dbh->selectrow_array(
                q|
                SELECT finetype FROM categories;
            |
            );
            if ($bulkdata) {
                say $out YELLOW,
                    "Data was found in 'finetype' column in 'categories' table. Please remove this data and run the update again.";
            } else {
                $dbh->do("ALTER TABLE categories DROP COLUMN finetype");
                say $out "Removed 'finetype' column from 'categories' table";
            }
        }

        if ( column_exists( 'categories', 'issuelimit' ) ) {
            my ($bulkdata) = $dbh->selectrow_array(
                q|
                SELECT issuelimit FROM categories;
            |
            );
            if ($bulkdata) {
                say $out YELLOW,
                    "Data was found in 'issuelimit' column in 'categories' table. Please remove this data and run the update again.";
            } else {
                $dbh->do("ALTER TABLE categories DROP COLUMN issuelimit");
                say $out "Removed 'issuelimit' column from 'categories' table";
            }
        }

        say $out WHITE, "Bug 35539: All done.";
    },
};
