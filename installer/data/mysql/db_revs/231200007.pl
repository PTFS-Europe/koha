use Modern::Perl;

use Term::ANSIColor;

return {
    bug_number  => "35681",
    description => "Test DB Rev output",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        say $out colored("Something in red is a warning", 'red');
        say $out colored("Somthing in yellow is a call to action", 'yellow');
        say $out colored("Something in blue is for information only", 'blue');
        say $out colored("You could use 'WHITE' too?", 'white');
        say $out "Or leave color off and stick to default";
    },
};
