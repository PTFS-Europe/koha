$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    if (TableExists('deletedbiblio') && TableExists('deletedbiblioitems') && TableExists('deletedbiblio_metadata')) {
        $dbh->do( "ALTER TABLE biblio ADD COLUMN deleted_on datetime DEFAULT NULL" ) or warn $DBI::errstr;
        $dbh->do( "ALTER TABLE biblioitems ADD COLUMN deleted_on datetime DEFAULT NULL" ) or warn $DBI::errstr;
        $dbh->do( "ALTER TABLE biblio_metadata ADD COLUMN deleted_on datetime DEFAULT NULL" ) or warn $DBI::errstr;
        $dbh->do( "ALTER TABLE items ADD COLUMN deleted_on datetime DEFAULT NULL" ) or warn $DBI::errstr;

        # Need to disable foreign keys on deletedbiblio_metadata to avoid cascading deletes from deletedbiblio
        # Bug 17196 introduced a mismatch in foreign keys of deletedbiblio_metadata, so any key must be dropped
        DropAllForeignKeys('deletedbiblio_metadata');
        $dbh->do( "INSERT IGNORE INTO biblio SELECT *, timestamp AS deleted_on FROM deletedbiblio" ) or warn $DBI::errstr;
        # We also need to make sure foreign keys references are in place, as Mysql < 5.7 aborts on foreign key errors
        $dbh->do( "INSERT IGNORE INTO biblioitems (
            SELECT *, timestamp AS deleted_on FROM deletedbiblioitems
            WHERE biblionumber IN (SELECT biblionumber FROM biblio)
        )" ) or warn $DBI::errstr;
        # biblio_metadata needs special handling since there is an extra autoincrement id that cannot be moved
        $dbh->do( "INSERT IGNORE INTO biblio_metadata (biblionumber, format, marcflavour, metadata, timestamp, deleted_on) (
            SELECT biblionumber, format, marcflavour, metadata, timestamp, timestamp AS deleted_on FROM deletedbiblio_metadata
            WHERE biblionumber IN (SELECT biblionumber FROM biblio)
        )" ) or warn $DBI::errstr;
        $dbh->do( "INSERT IGNORE INTO items (
            SELECT *, timestamp AS deleted_on FROM deleteditems
            WHERE biblioitemnumber IN (SELECT biblioitemnumber FROM biblioitems)
            AND homebranch IN (SELECT homebranch FROM branches)
            AND holdingbranch IN (SELECT holdingbranch FROM branches)
            AND biblionumber IN (SELECT biblionumber FROM biblio)
        )" ) or warn $DBI::errstr;

        # Check if any rows could not be moved, if so, rename table with underscore for checking, otherwise drop them
        {
            my $sth = $dbh->prepare("DELETE FROM deleteditems WHERE itemnumber IN (SELECT itemnumber FROM items)");
            $sth->execute();
            $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deleteditems");
            $sth->execute();
            my $row = $sth->fetchrow_hashref;
            if ($row->{count}) {
                print "Warning to database administrator:\n"
                    . "There were $row->{count} deleteditems that could not be moved, please check '_deleteditems'.\n";
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
                print "Warning to database administrator:\n"
                    . "There were $row->{count} deletedbiblio_metadata that could not be moved, please check '_deletedbiblio_metadata'.\n";
                $dbh->do("RENAME TABLE deletedbiblio_metadata TO _deletedbiblio_metadata");
            } else {
                $dbh->do("DROP TABLE deletedbiblio_metadata");
            }
        }

        {
            my $sth = $dbh->prepare("DELETE FROM deletedbiblioitems WHERE biblioitemnumber IN (SELECT biblioitemnumber FROM biblioitems)");
            $sth->execute();
            $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deletedbiblioitems");
            $sth->execute();
            my $row = $sth->fetchrow_hashref;
            if ($row->{count}) {
                print "Warning to database administrator:\n"
                    . "There were $row->{count} deletedbiblioitems that could not be moved, please check '_deletedbiblioitems'.\n";
                $dbh->do("RENAME TABLE deletedbiblioitems TO _deletedbiblioitems");
            } else {
                $dbh->do("DROP TABLE deletedbiblioitems");
            }
        }

        {
            my $sth = $dbh->prepare("DELETE FROM deletedbiblio WHERE biblionumber IN (SELECT biblionumber FROM biblio)");
            $sth->execute();
            $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM deletedbiblio");
            $sth->execute();
            my $row = $sth->fetchrow_hashref;
            if ($row->{count}) {
                print "Warning to database administrator:\n"
                . "There were $row->{count} deletedbiblio that could not be moved, please check '_deletedbiblio'.\n";
                $dbh->do("RENAME TABLE deletedbiblio TO _deletedbiblio");
            } else {
                $dbh->do("DROP TABLE deletedbiblio");
            }
        }
    }

    {
        $dbh->do("UPDATE systempreferences SET options='Koha''s deleted biblios will never be removed (persistent), might be removed (transient), or will always be removed (no)' WHERE variable='OAI-PMH:DeletedRecord'") or warn $DBI::errstr;
    }

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 20271 - Merge deletedbiblio* and deleteitems tables with their alive cousins)\n";
}
