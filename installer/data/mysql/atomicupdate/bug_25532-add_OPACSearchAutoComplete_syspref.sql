$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{ INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ( "OPACSearchAutoComplete", 0, NULL, "Enable a search suggestion to the OPAC Search box.","YesNo" ) });

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 25532 - Add a wikipedia-style search suggestion feature to the OPAC)\n";
}
