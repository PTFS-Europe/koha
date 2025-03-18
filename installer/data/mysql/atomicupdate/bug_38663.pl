use Modern::Perl;

return {
    bug_number  => "38663",
    description => "Add additional fields to libraries",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $sth = $dbh->prepare("SHOW COLUMNS FROM additional_field_values WHERE Field = 'record_id'");
        $sth->execute();
        my $column_info = $sth->fetchrow_hashref();

        if ( $column_info && $column_info->{Type} eq 'int(11)' ) {

            # Only run the migration if record_id is still an integer type
            say $out "Converting record_id from int(11) to VARCHAR(11)...\n";

            $dbh->do(
                q{ ALTER TABLE additional_field_values ADD COLUMN new_record_id VARCHAR(11) NOT NULL DEFAULT ''; });
            $dbh->do(q{ UPDATE additional_field_values SET new_record_id = CAST(record_id AS CHAR(11)); });
            $dbh->do(q{ ALTER TABLE additional_field_values DROP COLUMN record_id; });
            $dbh->do(q{ ALTER TABLE additional_field_values RENAME COLUMN new_record_id TO record_id; });

            say $out "Converted record_id to VARCHAR";
        } else {

            # Either the column doesn't exist or it's already been converted
            say $out "No conversion needed for record_id column.";
        }
    }
};
