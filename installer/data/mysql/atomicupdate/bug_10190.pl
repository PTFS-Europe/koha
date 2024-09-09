use Modern::Perl;

return {
    bug_number  => "10190",
    description => "Migrate overduerules to circulation_rules",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $do_it = 0;
        if ($do_it) { 

        # Populate empty overduerules table for missing categories
        $dbh->do(
            q|
            INSERT IGNORE INTO overduerules (branchcode, categorycode)
            SELECT '', categorycode
            FROM categories
            WHERE categorycode NOT IN (SELECT categorycode FROM overduerules);
        |
        );

        # Fetch all overdue rules
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

        # Initialize hashes to store the frequency of delays, notices, and mtt per group (1, 2, 3)
        my %branchcodes;
        my %delay_count;
        my %notice_count;
        my %mtt_count;
        my %restrict_count;

        # Populate the hashes with the frequency of each value by group
        for my $rule ( @{$rules} ) {
            my $branchcode = $rule->{'branchcode'};
            $branchcodes{$branchcode} = 1;

            foreach my $i ( 1 .. 3 ) {
                my $delay    = $rule->{"delay$i"}                   // '';
                my $notice   = $rule->{"letter$i"}                  // '';
                my $mtt      = $rule->{"message_transport_type_$i"} // '';
                my $restrict = $rule->{"debarred$i"}                // '';

                # Increment counts only if values are defined
                $delay_count{$branchcode}{$i}{$delay}++       if defined $delay;
                $notice_count{$branchcode}{$i}{$notice}++     if defined $notice;
                $mtt_count{$branchcode}{$i}{$mtt}++           if defined $mtt;
                $restrict_count{$branchcode}{$i}{$restrict}++ if defined $restrict;
            }
        }

        # Find the most frequent delay, notice, and mtt for each branchcode and group
        my ( %most_frequent_delay, %most_frequent_notice, %most_frequent_mtt, %most_frequent_restrict );
        for my $branchcode ( keys %branchcodes ) {
            foreach my $i ( 1 .. 3 ) {

                # Find the most frequent delay in group $i
                my $max_delay_count = 0;
                for my $delay ( keys %{ $delay_count{$branchcode}{$i} } ) {
                    if ( $delay_count{$branchcode}{$i}{$delay} > $max_delay_count ) {
                        $max_delay_count = $delay_count{$branchcode}{$i}{$delay};
                        $most_frequent_delay{$branchcode}{$i} = $delay;
                    }
                }

                # Find the most frequent notice in group $i
                my $max_notice_count = 0;
                for my $notice ( keys %{ $notice_count{$branchcode}{$i} } ) {
                    if ( $notice_count{$branchcode}{$i}{$notice} > $max_notice_count ) {
                        $max_notice_count = $notice_count{$branchcode}{$i}{$notice};
                        $most_frequent_notice{$branchcode}{$i} = $notice;
                    }
                }

                # Find the most frequent mtt in group $i
                my $max_mtt_count = 0;
                for my $mtt ( keys %{ $mtt_count{$branchcode}{$i} } ) {
                    if ( $mtt_count{$branchcode}{$i}{$mtt} > $max_mtt_count ) {
                        $max_mtt_count = $mtt_count{$branchcode}{$i}{$mtt};
                        $most_frequent_mtt{$branchcode}{$i} = $mtt;
                    }
                }

                # Find the most frequent mtt in group $i
                my $max_restrict_count = 0;
                for my $restrict ( keys %{ $restrict_count{$branchcode}{$i} } ) {
                    if ( $restrict_count{$branchcode}{$i}{$restrict} > $max_restrict_count ) {
                        $max_restrict_count = $restrict_count{$branchcode}{$i}{$restrict};
                        $most_frequent_restrict{$branchcode}{$i} = $restrict;
                    }
                }
            }
        }

        # Migrate rules from overduerules to circulation_rules, skipping most frequent values as those will be our defaults
        my $insert = $dbh->prepare(
            "INSERT IGNORE INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value) VALUES (?, ?, ?, ?, ?)"
        );

        my $itemtype = undef;
        for my $rule ( @{$rules} ) {
            my $branchcode   = $rule->{'branchcode'}   || undef;
            my $categorycode = $rule->{'categorycode'} || undef;

            my $branchcode_key = $branchcode // '';
            foreach my $i ( 1 .. 3 ) {

                # Insert the delay rule for group $i, skipping if it matches the most frequent delay
                if ( my $delay = $rule->{"delay$i"} ) {
                    $delay ||= '';
                    unless ( $delay eq $most_frequent_delay{$branchcode_key}{$i} ) {
                        $delay ||= undef;
                        say $out "Inserting $branchcode:$categorycode:$itemtype overdue_$i" . '_delay: ' . $delay;
                        $insert->execute(
                            $branchcode,
                            $categorycode,
                            $itemtype,
                            "overdue_$i" . '_delay',
                            $delay
                        );
                    }
                }

                # Insert the notice rule for group $i, skipping if it matches the most frequent notice
                if ( my $notice = $rule->{"letter$i"} ) {
                    unless ( $notice eq $most_frequent_notice{$branchcode_key}{$i} ) {
                        say $out "Inserting $branchcode:$categorycode:$itemtype overdue_$i" . '_notice: ' . $notice;
                        $insert->execute(
                            $branchcode,
                            $categorycode,
                            $itemtype,
                            "overdue_$i" . '_notice',
                            $notice
                        );
                    }
                }

                # Insert the message transport type rule for group $i, skipping if it matches the most frequent mtt
                if ( my $mtt = $rule->{"message_transport_type_$i"} ) {
                    unless ( $mtt eq $most_frequent_mtt{$branchcode_key}{$i} ) {
                        say $out "Inserting $branchcode:$categorycode:$itemtype overdue_$i" . '_mtt: ' . $mtt;
                        $insert->execute(
                            $branchcode,
                            $categorycode,
                            $itemtype,
                            "overdue_$i" . '_mtt',
                            $mtt
                        );
                    }
                }

                # Insert the restrict rule for group $i
                if ( my $restrict = $rule->{"debarred$i"} ) {
                    unless ( $restrict eq $most_frequent_restrict{$branchcode_key}{$i} ) {
                        say $out "Inserting $branchcode:$categorycode:$itemtype overdue_$i" . '_restrict: ' . $restrict;
                        $insert->execute(
                            $branchcode,
                            $categorycode,
                            $itemtype,
                            "overdue_$i" . '_restrict',
                            $restrict
                        );
                    }
                }
            }
        }

        # Insert the default rules for each group
        for my $branchcode ( keys %branchcodes ) {
            my $branchcode_value = $branchcode || undef;
            foreach my $i ( 1 .. 3 ) {
                my $most_frequent_delay = $most_frequent_delay{$branchcode}{$i};
                say $out "Inserting $branchcode_value:undef:$itemtype default most frequent delay for overdue_$i: " . $most_frequent_delay;
                $insert->execute(
                    $branchcode_value,
                    undef,
                    $itemtype,
                    "overdue_${i}_delay",
                    $most_frequent_delay
                );

                my $most_frequent_notice = $most_frequent_notice{$branchcode}{$i};
                say $out "Inserting $branchcode_value:undef:undef default most frequent notice for overdue_$i: " . $most_frequent_notice;
                $insert->execute(
                    $branchcode_value,
                    undef,
                    undef,
                    "overdue_${i}_notice",
                    $most_frequent_notice
                );

                my $most_frequent_mtt = $most_frequent_mtt{$branchcode}{$i};
                say $out "Inserting $branchcode_value:undef:undef default most frequent mtt for overdue_$i: " . $most_frequent_mtt;
                $insert->execute(
                    $branchcode_value,
                    undef,
                    undef,
                    "overdue_${i}_mtt",
                    $most_frequent_mtt
                );

                my $most_frequent_restrict = $most_frequent_restrict{$branchcode}{$i};
                say $out "Inserting $branchcode_value:undef:undef default most frequent restrict for overdue_$i: " . $most_frequent_restrict;
                $insert->execute(
                    $branchcode_value,
                    undef,
                    undef,
                    "overdue_${i}_restrict",
                    $most_frequent_restrict
                );

            }
        }
        } else {
            say "Nothing to do this time";
        }
    }
};
