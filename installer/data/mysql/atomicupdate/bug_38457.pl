use Modern::Perl;

return {
    bug_number  => "38457",
    description => "Add additional fields to debit types",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $sth = $dbh->prepare("SHOW COLUMNS FROM additional_field_values WHERE Field = 'record_id'");
        $sth->execute();
        my $column_info = $sth->fetchrow_hashref();

        if ( $column_info && $column_info->{Type} eq 'VARCHAR(11)' ) {
            $dbh->do(q{ ALTER TABLE additional_field_values MODIFY record_id VARCHAR(80) NOT NULL DEFAULT ''; });
            say $out "Converted record_id to VARCHAR(80)";
        }
    },
};
