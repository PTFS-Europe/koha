use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "31391",
    description => "Staff-side recalls",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        try {
            $dbh->do(q{UPDATE systempreferences SET value = "off", options = "off|opac|staff|opac_and_staff", type="Choice" WHERE variable = "UseRecalls" AND value = "0"});
            $dbh->do(q{UPDATE systempreferences SET value = "opac", options = "off|opac|staff|opac_and_staff", type="Choice" WHERE variable = "UseRecalls" AND value = "1"});
            say_success( $out, "Updated system preference 'UseRecalls' to include interface choices" );
        }
        catch {
            say_failure( $out, "Database modification failed with errors: $_" );
        };
    },
};
