use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "XXXXX",
    description => "Add table for storing Shibboleth SSO field mappings",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};
        
        unless ( TableExists('shibboleth_field_mappings') ) {
            $dbh->do(q{
                CREATE TABLE shibboleth_field_mappings (
                    mapping_id int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    idp_field varchar(255) NOT NULL COMMENT 'Field name from the identity provider',
                    koha_field varchar(255) NOT NULL COMMENT 'Corresponding field in Koha borrowers table',
                    is_matchpoint tinyint(1) NOT NULL DEFAULT 0 COMMENT 'If this field is used to match existing users',
                    PRIMARY KEY (mapping_id),
                    UNIQUE KEY koha_field_idx (koha_field),
                    KEY idp_field_idx (idp_field)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });

            $dbh->do(q{
                INSERT INTO systempreferences (variable,value,explanation,options,type) 
                VALUES ('ShibbolethAuthentication','0','Enable or disable Shibboleth authentication integration','0|1','YesNo')
            });

            say $out "Added new table 'shibboleth_field_mappings'";
        } else {
            say_info($out, "Table 'shibboleth_field_mappings' already exists");
        }

        unless ( TableExists('shibboleth_config') ) {
            $dbh->do(q{
                CREATE TABLE shibboleth_config (
                    shibboleth_config_id int(11) NOT NULL AUTO_INCREMENT COMMENT 'primary key',
                    enable_opac_sso tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Enable Shibboleth SSO for OPAC',
                    enable_staff_sso tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Enable Shibboleth SSO for staff interface', 
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
    },
};
