use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "10190",
    description => "Migrate overduerules to circulation_rules",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $rules = $dbh->selectall_arrayref(
            q|
            SELECT
                o.overduerules_id,
                o.branchcode,
                o.categorycode,
                o.delay1,
                o.letter1,
                o.debarred1,
                o.delay2,
                o.debarred2,
                o.letter2,
                o.delay3,
                o.letter3,
                o.debarred3,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 1 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS message_transport_type_1,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 2 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS message_transport_type_2,
                GROUP_CONCAT(
                    CASE WHEN ott.letternumber = 3 THEN ott.message_transport_type END
                    ORDER BY ott.message_transport_type ASC
                ) AS message_transport_type_3
            FROM
                overduerules o
            LEFT JOIN
                overduerules_transport_types ott
                ON o.overduerules_id = ott.overduerules_id
            GROUP BY
                o.overduerules_id,
                o.branchcode,
                o.categorycode,
                o.delay1,
                o.letter1,
                o.debarred1,
                o.delay2,
                o.debarred2,
                o.letter2,
                o.delay3,
                o.letter3,
                o.debarred3
            |,
            { Slice => {} }
        );

        my $insert = $dbh->prepare(
            "INSERT IGNORE INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value) VALUES (?, ?, ?, ?, ?)"
        );

        my $itemtype = undef;
        for my $rule ( @{$rules} ) {
            my $branchcode   = $rule->{'branchcode'}   || undef;
            my $categorycode = $rule->{'categorycode'} || undef;

            foreach my $i ( 1 .. 3 ) {

                # Delay
                say $out, "Inserting overdue_$i" . '_delay';
                $insert->execute(
                    $branchcode,
                    $categorycode,
                    $itemtype,
                    "overdue_$i" . '_delay',
                    $rule->{"delay$i"}
                );

                # Notice
                say $out, "Inserting overdue_$i" . '_notice';
                $insert->execute(
                    $branchcode,
                    $categorycode,
                    $itemtype,
                    "overdue_$i" . '_notice',
                    $rule->{"letter$i"}
                );

                # Message Transport Type
                say $out, "Inserting overdue_$i" . '_mtt';
                $insert->execute(
                    $branchcode,
                    $categorycode,
                    $itemtype,
                    "overdue_$i" . '_mtt',
                    $rule->{"message_transport_type_$i"}
                );

                # Restrict
                say $out, "Inserting overdue_$i" . '_restrict';
                $insert->execute(
                    $branchcode,
                    $categorycode,
                    $itemtype,
                    "overdue_$i" . '_restrict',
                    $rule->{"debarred$i"}
                );
            }
        }
    },
};
