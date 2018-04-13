$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do( "ALTER TABLE biblio ADD COLUMN deleted_at datetime DEFAULT NULL" ) or warn $DBI::errstr;
    $dbh->do( "ALTER TABLE biblioitems ADD COLUMN deleted_at datetime DEFAULT NULL" ) or warn $DBI::errstr;
    $dbh->do( "ALTER TABLE biblio_metadata ADD COLUMN deleted_at datetime DEFAULT NULL" ) or warn $DBI::errstr;
    $dbh->do( "ALTER TABLE items ADD COLUMN deleted_at datetime DEFAULT NULL" ) or warn $DBI::errstr;

    # Need to disable foreign keys on deletedbiblio_metadata to avoid cascading deletes from deletedbiblio
    # Bug 17196 introduced a mismatch in foreign keys of deletedbiblio_metadata, so dropping would fail
    $dbh->do( "ALTER TABLE deletedbiblio_metadata DISABLE KEYS" );

    $dbh->do( "INSERT IGNORE INTO biblio SELECT *, timestamp AS deleted_at FROM deletedbiblio" ) or warn $DBI::errstr;
    $dbh->do( "INSERT IGNORE INTO biblioitems SELECT *, timestamp AS deleted_at FROM deletedbiblioitems" ) or warn $DBI::errstr;
    $dbh->do( "INSERT IGNORE INTO biblio_metadata SELECT *, timestamp AS deleted_at FROM deletedbiblio_metadata" ) or warn $DBI::errstr;
    $dbh->do( "INSERT IGNORE INTO items SELECT *, timestamp AS deleted_at FROM deleteditems" ) or warn $DBI::errstr;

    # Check if any rows could not be moved, if so, rename table with underscore for checking, otherwise drop them
    {
        my $sth = $dbh->prepare("DELETE FROM deleteditems WHERE itemnumber IN (SELECT itemnumber FROM items)");
        $sth->execute();
        $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deleteditems");
        $sth->execute();
        my $row = $sth->fetchrow_hashref;
        if ($row->{count}) {
            warn "There were $row->{count} deleteditems that could not be moved, please check '_deleteditems'.";
            $dbh->do("RENAME TABLE deleteditems TO _deleteditems");
        } else {
            $dbh->do("DROP TABLE deleteditems");
        }
    }

    {
        my $sth = $dbh->prepare("DELETE FROM deletedbiblio_metadata WHERE biblionumber IN (SELECT biblionumber FROM biblio_metadata)");
        $sth->execute();
        $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deletedbiblio_metadata");
        $sth->execute();
        my $row = $sth->fetchrow_hashref;
        if ($row->{count}) {
            warn "There were $row->{count} deletedbiblio_metadata that could not be moved, please check '_deletedbiblio_metadata'.";
            $dbh->do("RENAME TABLE deletedbiblio_metadata TO _deletedbiblio_metadata");
        } else {
            $dbh->do("DROP TABLE deletedbiblio_metadata");
        }
    }

    {
        my $sth = $dbh->prepare("DELETE FROM deletedbiblio WHERE biblionumber IN (SELECT biblionumber FROM biblio)");
        $sth->execute();
        $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deletedbiblio WHERE biblionumber NOT IN (SELECT biblionumber FROM deletedbiblioitems)");
        $sth->execute();
        my $row = $sth->fetchrow_hashref;
        if ($row->{count}) {
            warn "There were $row->{count} deletedbiblio that could not be moved, please check '_deletedbiblio'.";
            $dbh->do("RENAME TABLE deletedbiblio TO _deletedbiblio");
        } else {
            $dbh->do("DROP TABLE deletedbiblio");
        }
    }

    {
        my $sth = $dbh->prepare("DELETE FROM deletedbiblioitems WHERE biblioitemnumber IN (SELECT biblioitemnumber FROM biblioitems)");
        $sth->execute();
        $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deletedbiblioitems");
        $sth->execute();
        my $row = $sth->fetchrow_hashref;
        if ($row->{count}) {
            warn "There were $row->{count} deletedbiblioitems that could not be moved, please check '_deletedbiblioitems'.";
            $dbh->do("RENAME TABLE deletedbiblioitems TO _deletedbiblioitems");
        } else {
            $dbh->do("DROP TABLE deletedbiblioitems");
        }
    }


    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 20271 - Merge deletedbiblio* and deleteitems tables with their alive cousins)\n";
}
