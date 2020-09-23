$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('CircConfirmItemParts', '0', NULL, 'Require staff to confirm that all parts of an item are present at checkin/checkout.', 'YesNo') });

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 25261 - Add CircConfirmItemParts syspref)\n";
}
