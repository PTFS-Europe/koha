$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do( q{ INSERT IGNORE INTO systempreferences (variable, value, explanation, options, type) VALUES ('CookieConsentBar', '', 'Show the following HTML in the cookie consent bar that is displayed at the bottom of the screen', '70|10', 'Textarea'); } );

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 27378 - Add CookieConsentBar syspref)\n";
}
