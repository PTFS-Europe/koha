$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    my ($text) = $dbh->selectrow_array('SELECT content FROM letter WHERE module = "circulation" AND code = "AUTO_RENEWALS" AND content NOT LIKE "%too_unseen%"');

    if ($text) {
        my $find = qr/^\[\% (IF|ELSIF) checkout.auto_renew_error == 'too_many' \%\]$/;
        my @lines_in = split /^/, $text;
        my @lines_out = ();
        foreach my $line(@lines_in) {
            if ($line =~ $find) {
                if ($1) {
                    my $newline_test = $1 eq 'IF' ? 'IF' : 'ELSIF';
                    $line =~ s/\bIF\b/ELSIF/;
                    push @lines_out, "[% $newline_test checkout.auto_renew_error == 'too_unseen' %]\n";
                    push @lines_out, "You have reach the maximum of consecutive renewals without visiting the library.\n";
                }
            }
            push @lines_out, $line;
        }
        if (scalar @lines_out > 0) {
            my $joined = join "", @lines_out;
            $dbh->do(q{UPDATE letter SET content = ? WHERE module = "circulation" AND code = "AUTO_RENEWALS"}, undef, ($joined));
        }
    }


    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 24083 - Add issues.unseen_renewals & old_issues.unseen_renewals)\n";
}
