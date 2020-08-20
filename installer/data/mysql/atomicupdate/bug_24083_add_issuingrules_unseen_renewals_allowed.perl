$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    if( !column_exists( 'issuingrules', 'unseen_renewals_allowed' ) ) {
        $dbh->do( q| ALTER TABLE issuingrules ADD unseen_renewals_allowed SMALLINT(6) DEFAULT NULL AFTER renewalsallowed | );
    }

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 24083 - Add issuingrules.unseen_renewals_allowed)\n";
}
