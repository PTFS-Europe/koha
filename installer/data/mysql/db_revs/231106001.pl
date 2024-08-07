use Modern::Perl;

return {
    bug_number  => "36819",
    description => "Change barcode width value if it still has the wrong default value",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $affected = $dbh->do(q{UPDATE creator_layouts SET scale_width = '0.800000' WHERE scale_width = '0.080000';});

        if ($affected) {
            say $out "Changed the barcode width in patron card creator default layout from 8% to 80%.";
        } else {
            say $out "No patron card creator layouts found with 8% width, no changes required.";
        }
    },
};
