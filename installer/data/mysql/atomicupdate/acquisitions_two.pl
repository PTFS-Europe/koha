use Modern::Perl;

return {
    bug_number  => "BUG_NUMBER",
    description => "Anything relevant to acq2.0 that may end up in a bug for core",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'library_groups', 'ft_acquisitions' ) ) {
            $dbh->do(
                "ALTER TABLE `library_groups` ADD COLUMN `ft_acquisitions` tinyint(1) NOT NULL DEFAULT 0 AFTER `ft_local_float_group`"
            );
        }

    }
};
