use Modern::Perl;

return {
    bug_number  => "31391",
    description => "Staff-side recalls",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{ INSERT IGNORE INTO authorised_values (category, authorised_value, lib) VALUES ('HOLD_CANCELLATION','RECALLED','Hold was converted to a recall') }
        );

        say $out "Added RECALLED value to HOLD_CANCELLATION authorised value category";
    },
};
