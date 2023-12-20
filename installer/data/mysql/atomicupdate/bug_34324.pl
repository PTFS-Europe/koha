use Modern::Perl;

return {
    bug_number  => "34324",
    description => "Add opac_problem to source enum of tickets table",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            "ALTER TABLE `tickets` MODIFY COLUMN `source` enum('catalog','opac_problem') NOT NULL DEFAULT 'catalog' COMMENT 'source of ticket'"
        );
        say $out "Added opac_problem to source enum of 'tickets.source'";
    },
};
