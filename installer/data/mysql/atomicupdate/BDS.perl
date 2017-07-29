$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    $dbh->do( "INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('BDSOpacEnable', '0', 'Enable or disable BDS enhanced content in the OPAC', NULL, 'YesNo'),('BDSStaffEnable', '0', 'Enable or disable BDS enhanced content in the Staff Interface', NULL, 'YesNo'),('DBMCode','','NULL','BDS Customer DBM Code','Free');" );

    # or perform some test and warn
    # if( !column_exists( 'biblio', 'biblionumber' ) ) {
    #    warn "There is something wrong";
    # }

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug XXXXX - description)\n";
}
