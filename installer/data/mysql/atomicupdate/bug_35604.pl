use Modern::Perl;
return {
    bug_number  => "35604",
    description => "Add new AutoILLBackend and AutoILLBackendPriority system preferences",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        $dbh->do(
            q{ INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('AutoILLBackend','',NULL,'Enable automatic backend selection','1'); }
        );
        say $out "Added new system preference 'AutoILLBackend'";

        $dbh->do(
            q{ INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('AutoILLBackendPriority','',NULL,'Set the automatic backend selection priority','ILLBackends'); }
        );
        say $out "Added new system preference 'AutoILLBackendPriority'";
    },
};
