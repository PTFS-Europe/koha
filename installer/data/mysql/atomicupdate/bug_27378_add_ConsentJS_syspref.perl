$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do( q| INSERT IGNORE INTO systempreferences (variable, value, explanation, options, type) VALUES ('ConsentJS', '', 'Specify Javascript that requires user consent to run (e.g. tracking code)', '', 'Free'); | );

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 27378 - Add ConsentJS syspref)\n";
}
