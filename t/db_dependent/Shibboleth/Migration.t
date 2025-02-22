use Modern::Perl;
use Test::More tests => 46;
use t::lib::TestBuilder;
use t::lib::Mocks;
use XML::Simple;

use Koha::Database;
use C4::Installer qw( TableExists column_exists );

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

# Create TableExists sub for atomic update
BEGIN {
    *TableExists = \&C4::Installer::TableExists;
}

# Drop tables first to ensure clean state
my $dbh = C4::Context->dbh;
$dbh->do("DROP TABLE IF EXISTS shibboleth_config");
$dbh->do("DROP TABLE IF EXISTS shibboleth_field_mappings"); 
$dbh->do("DELETE FROM systempreferences WHERE variable IN ('ShibbolethAuthentication', 'staffShibOnly', 'OPACShibOnly')");

# Create test XML config
my $xml_content = <<'EOT';
<?xml version="1.0" encoding="UTF-8"?>
<yazgfs>
  <config>
    <useshibboleth>1</useshibboleth>
    <shibboleth>
      <autocreate>1</autocreate>
      <sync>1</sync>
      <welcome>1</welcome>
      <matchpoint>email</matchpoint>
      <mapping>
        <email is="mail"></email>
        <userid is="userid"></userid>
        <cardnumber is="id"></cardnumber>
        <firstname is="givenname"></firstname>
        <surname is="surname"></surname>
        <branchcode content="MAIN"></branchcode>
        <categorycode content="DEFAULT"></categorycode>
        <password is="digitalid"></password>
        <borrowernotes content="AUTOMATIC_USER"></borrowernotes>
      </mapping>
    </shibboleth>
  </config>
</yazgfs>
EOT

# Write test config to temporary file
use File::Temp qw(tempfile);
my ($fh, $filename) = tempfile();
print $fh $xml_content;
close $fh;

# Set KOHA_CONF to point to our test file
$ENV{KOHA_CONF} = $filename;

# Add test sysprefs
$schema->resultset('Systempreference')->update_or_create(
    {
        variable => 'staffShibOnly',
        value    => 1,
        explanation => 'If ON enables shibboleth only authentication for the staff client',
        type => 'YesNo'
    }
);

$schema->resultset('Systempreference')->update_or_create(
    {
        variable => 'OPACShibOnly',
        value    => 1,
        explanation => 'If ON enables shibboleth only authentication for the opac',
        type => 'YesNo'
    }
);

# Set KOHA_CONF env var before running update
local $ENV{KOHA_CONF} = $filename;

# Run the migration
my $update_dir = 'installer/data/mysql/atomicupdate/';
my $file = 'bug_xxxxx_add_shibboleth_tables.pl';

# Load and run atomic update
require $update_dir . $file;
my $ret = do $update_dir . $file;
my $update = $ret->{up}->({
    dbh => $dbh,
    out => \*STDOUT
});

# Test the tables were created
ok($dbh->selectrow_array(q{SHOW TABLES LIKE 'shibboleth_config'}), 
   "shibboleth_config table exists");
ok($dbh->selectrow_array(q{SHOW TABLES LIKE 'shibboleth_field_mappings'}),
   "shibboleth_field_mappings table exists");

# Test ShibbolethAuthentication syspref
my ($exists) = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM systempreferences WHERE variable = 'ShibbolethAuthentication'"
);
ok($exists, "ShibbolethAuthentication syspref exists");

# Test useshibboleth value migrated 
my ($value) = $dbh->selectrow_array(
    "SELECT value FROM systempreferences WHERE variable = 'ShibbolethAuthentication'"
);
is($value, 1, "useshibboleth value migrated correctly to ShibbolethAuthentication syspref");

# Test sysprefs migration
my $config = $dbh->selectrow_hashref(
    "SELECT force_opac_sso, force_staff_sso FROM shibboleth_config"
);
is($config->{force_opac_sso}, 1, "OPACShibOnly migrated correctly");
is($config->{force_staff_sso}, 1, "staffShibOnly migrated correctly");

my $old_prefs = $dbh->selectall_arrayref(
    "SELECT variable FROM systempreferences 
     WHERE variable IN ('staffShibOnly','OPACShibOnly')"
);
is(scalar @$old_prefs, 0, "Old sysprefs were removed");

# Test XML config migration
$config = $dbh->selectrow_hashref(
    "SELECT autocreate, sync, welcome FROM shibboleth_config"
);
is($config->{autocreate}, 1, "autocreate setting migrated");
is($config->{sync}, 1, "sync setting migrated"); 
is($config->{welcome}, 1, "welcome setting migrated");

my $mappings = $dbh->selectall_hashref(
    "SELECT koha_field, idp_field, default_content, is_matchpoint 
     FROM shibboleth_field_mappings",
    'koha_field'
);

my $expected_mappings = {
    email => {
        idp_field => 'mail',
        is_matchpoint => 1,
        default_content => '',
    },
    userid => {
        idp_field => 'userid',
        is_matchpoint => 0,
        default_content => '',
    },
    cardnumber => {
        idp_field => 'id',
        is_matchpoint => 0,
        default_content => '',
    },
    firstname => {
        idp_field => 'givenname',
        is_matchpoint => 0,
        default_content => '',
    },
    surname => {
        idp_field => 'surname',
        is_matchpoint => 0,
        default_content => '',
    },
    branchcode => {
        idp_field => '',
        is_matchpoint => 0,
        default_content => 'MAIN',
    },
    categorycode => {
        idp_field => '',
        is_matchpoint => 0,
        default_content => 'DEFAULT',
    },
    password => {
        idp_field => 'digitalid',
        is_matchpoint => 0,
        default_content => '',
    },
    borrowernotes => {
        idp_field => '',
        is_matchpoint => 0,
        default_content => 'AUTOMATIC_USER',
    },
};

for my $field (sort keys %$expected_mappings) {
    ok(exists $mappings->{$field}, "Mapping exists for $field");
    is($mappings->{$field}->{idp_field}, $expected_mappings->{$field}->{idp_field}, 
       "IDP field correct for $field");
    is($mappings->{$field}->{default_content}, $expected_mappings->{$field}->{default_content},
       "Default content correct for $field");
    is($mappings->{$field}->{is_matchpoint}, $expected_mappings->{$field}->{is_matchpoint},
       "Matchpoint flag correct for $field");
}

$schema->storage->txn_rollback;
