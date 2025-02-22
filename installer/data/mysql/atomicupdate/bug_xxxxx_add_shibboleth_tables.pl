use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);
use XML::Simple;

return {
    bug_number  => "XXXXX",
    description => "Add table for storing Shibboleth SSO field mappings",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Get XML config once
        my $xml_config;
        my $koha_conf = $ENV{KOHA_CONF};
        if ($koha_conf) {
            $xml_config = XML::Simple->new->XMLin($koha_conf);
        }
        
        unless ($xml_config) {
            say_warning($out, "Could not load XML config from KOHA_CONF. XML settings will not be migrated.");
        }
        
        unless ( TableExists('shibboleth_field_mappings') ) {
            $dbh->do(q{
                CREATE TABLE shibboleth_field_mappings (
                    mapping_id int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    idp_field varchar(255) COMMENT 'Field name from the identity provider',
                    koha_field varchar(255) NOT NULL COMMENT 'Corresponding field in Koha borrowers table',
                    is_matchpoint tinyint(1) NOT NULL DEFAULT 0 COMMENT 'If this field is used to match existing users',
                    default_content varchar(255) DEFAULT NULL COMMENT 'Default content for this field if not provided by the IdP',
                    PRIMARY KEY (mapping_id),
                    UNIQUE KEY koha_field_idx (koha_field),
                    KEY idp_field_idx (idp_field)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });

            # Get useshibboleth value from XML 
            my $use_shibboleth = 0; # Default to 0
            if ($xml_config && $xml_config->{config} && defined $xml_config->{config}->{useshibboleth}) {
                $use_shibboleth = $xml_config->{config}->{useshibboleth};
            }

            # Insert ShibbolethAuthentication syspref 
            unless ( column_exists('systempreferences', 'ShibbolethAuthentication') ) {
                $dbh->do(q{
                    INSERT INTO systempreferences (variable,value,explanation,options,type) 
                    VALUES ('ShibbolethAuthentication',?,'Enable or disable Shibboleth authentication integration','0|1','YesNo')
                }, undef, $use_shibboleth);
            }

            say $out "Added new table 'shibboleth_field_mappings'";
        } else {
            say_info($out, "Table 'shibboleth_field_mappings' already exists");
        }

        unless ( TableExists('shibboleth_config') ) {
            $dbh->do(q{
                CREATE TABLE shibboleth_config (
                    shibboleth_config_id int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    force_opac_sso tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Force Shibboleth SSO for OPAC',
                    force_staff_sso tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Force Shibboleth SSO for staff interface', 
                    autocreate tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Automatically create new patrons',
                    sync tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Sync patron attributes on login',
                    welcome tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Send welcome email to new patrons',
                    PRIMARY KEY (shibboleth_config_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });

            say $out "Added new table 'shibboleth_config'";
        } else {
            say_info($out, "Table 'shibboleth_config' already exists");
        }

        # Only migrate sysprefs if config table exists
        if (TableExists('shibboleth_config')) {
            my $sth = $dbh->prepare("SELECT variable, value FROM systempreferences WHERE variable IN ('staffShibOnly', 'OPACShibOnly')");
            $sth->execute();
            my $old_prefs = {};
            while (my $row = $sth->fetchrow_hashref) {
                $old_prefs->{$row->{variable}} = $row->{value}; 
            }

            if (%$old_prefs) {
                $dbh->do(q{
                    INSERT INTO shibboleth_config 
                    (force_opac_sso, force_staff_sso) VALUES (?,?)
                }, undef, 
                    ($old_prefs->{OPACShibOnly} || 0),
                    ($old_prefs->{staffShibOnly} || 0)
                );

                $dbh->do(q{
                    DELETE FROM systempreferences 
                    WHERE variable IN ('staffShibOnly','OPACShibOnly')
                });
                say $out "Migrated and removed deprecated Shibboleth system preferences";
            }
        }

        # Only attempt XML migration if tables exist
        if (TableExists('shibboleth_config') && TableExists('shibboleth_field_mappings')) {
            if ($xml_config && $xml_config->{config} && $xml_config->{config}->{shibboleth}) {
                # Update existing config row 
                $dbh->do(q{
                    UPDATE shibboleth_config SET
                    autocreate = ?,
                    sync = ?,
                    welcome = ?
                }, undef,
                    ($xml_config->{config}->{shibboleth}->{autocreate} || 0),
                    ($xml_config->{config}->{shibboleth}->{sync} || 0), 
                    ($xml_config->{config}->{shibboleth}->{welcome} || 0)
                );

                # Migrate field mappings 
                my $mapping = $xml_config->{config}->{shibboleth}->{mapping};
                foreach my $koha_field (keys %$mapping) {
                    my $idp_field = $mapping->{$koha_field}->{is} || '';
                    my $default = $mapping->{$koha_field}->{content} || '';
                    my $is_matchpoint = ($koha_field eq $xml_config->{config}->{shibboleth}->{matchpoint}) ? 1 : 0;

                    $dbh->do(q{
                        INSERT INTO shibboleth_field_mappings
                        (koha_field, idp_field, default_content, is_matchpoint)
                        VALUES (?,?,?,?)
                    }, undef,
                        $koha_field,
                        $idp_field, 
                        $default,
                        $is_matchpoint
                    );
                }
                say $out "Migrated Shibboleth XML configuration";
            }
        }

        return 1;
    },
};
