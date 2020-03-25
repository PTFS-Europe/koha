$DBversion = 'XXX';
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS l10n_source (
            l10n_source_id INT(11) NOT NULL AUTO_INCREMENT,
            context VARCHAR(100) NULL DEFAULT NULL,
            source TEXT NOT NULL,
            PRIMARY KEY (l10n_source_id),
            KEY context_source (context, source(60))
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS l10n_target (
            l10n_target_id INT(11) NOT NULL AUTO_INCREMENT,
            l10n_source_id INT(11) NOT NULL,
            language VARCHAR(10) NOT NULL,
            translation TEXT NOT NULL,
            PRIMARY KEY (l10n_target_id),
            UNIQUE KEY l10n_source_language (l10n_source_id, language),
            FOREIGN KEY l10n_source (l10n_source_id) REFERENCES l10n_source (l10n_source_id)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
    });

    # Populate l10n_source and l10n_target for itemtypes
    $dbh->do(q{
        INSERT INTO l10n_source (context, source)
        SELECT DISTINCT 'itemtype', description FROM itemtypes
    });

    if (TableExists('localization')) {
        $dbh->do(q{
            INSERT INTO l10n_target (l10n_source_id, language, translation)
            SELECT DISTINCT l10n_source_id, lang, translation
            FROM localization
            JOIN itemtypes ON (localization.code = itemtypes.itemtype)
            JOIN l10n_source ON (itemtypes.description = l10n_source.source AND l10n_source.context = 'itemtype')
            WHERE entity = 'itemtypes'
        });

        $dbh->do('DROP TABLE localization');
    }


    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 24975 - l10n_source, l10n_target)\n";
}
