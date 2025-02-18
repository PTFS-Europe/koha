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
                    idp_field varchar(255) NOT NULL COMMENT 'field name from the identity provider',
                    koha_field varchar(255) NOT NULL COMMENT 'corresponding field in Koha borrowers table',
                    is_matchpoint tinyint(1) NOT NULL DEFAULT 0 COMMENT 'if this field is used to match existing users',
                    PRIMARY KEY (mapping_id),
                    UNIQUE KEY idp_field_idx (idp_field),
                    KEY koha_field_idx (koha_field)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            });

            say $out "Added new table 'shibboleth_field_mappings'";
            say_info($out, "This table will store mappings between Shibboleth IdP fields and Koha borrower fields");
        }
        else {
            say_info($out, "Table 'shibboleth_field_mappings' already exists");
        }
    },
};
