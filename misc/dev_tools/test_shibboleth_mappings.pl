#!/usr/bin/perl

use Modern::Perl;
use FindBin;
use lib "$FindBin::Bin/../../";

use Koha::ShibbolethFieldMapping;
use Koha::ShibbolethFieldMappings;
use Koha::ShibbolethConfig;
use Koha::ShibbolethConfigs;
use C4::Auth_with_shibboleth qw(shib_ok);
use Data::Dumper;

# Clear existing configs
print "\nClearing existing configurations...\n";
my $mappings = Koha::ShibbolethFieldMappings->new;
$mappings->delete;
my $configs = Koha::ShibbolethConfigs->new;
$configs->delete;

# Get XML config
print "\nTesting XML configuration access:\n";
my $xml_config = C4::Auth_with_shibboleth::_get_shib_config_old();

# Set up identical DB config
my $db_config = $configs->get_configuration;
$db_config->set({
    enable_opac_sso => $xml_config->{enable_opac_sso} // 0,
    enable_staff_sso => $xml_config->{enable_staff_sso} // 0,
    autocreate => $xml_config->{autocreate} // 0,
    sync => $xml_config->{sync} // 0,
    welcome => $xml_config->{welcome} // 0
})->store;

# Create test mappings from XML config
if ($xml_config && $xml_config->{mapping}) {
    while (my ($koha_field, $mapping) = each %{$xml_config->{mapping}}) {
        next unless $koha_field && $mapping->{is}; # Skip if either field is missing
        
        print "Creating mapping: $koha_field -> " . $mapping->{is} . "\n";
        
        eval {
            Koha::ShibbolethFieldMapping->new({
                idp_field => $mapping->{is},
                koha_field => $koha_field,
                is_matchpoint => ($koha_field eq $xml_config->{matchpoint}) ? 1 : 0
            })->store;
        };
        if ($@) {
            warn "Failed to create mapping for $koha_field: $@";
        }
    }
}

# Get DB config
my $new_config = C4::Auth_with_shibboleth::_get_shib_config();

# Test config equivalence
print "\nTesting config equivalence:\n";

# Test boolean settings
foreach my $setting (qw(enable_opac_sso enable_staff_sso autocreate sync welcome)) {
    my $xml_val = $xml_config->{$setting} ? 1 : 0;
    my $db_val = $new_config->{$setting} ? 1 : 0;
    print "$setting: XML=" . ($xml_val ? "true" : "false") . 
          " DB=" . ($db_val ? "true" : "false") . 
          " MATCH=" . ($xml_val == $db_val ? "YES" : "NO") . "\n";
}

# Test conditional behavior
print "\nTesting conditional behavior:\n";
print "XML if(config->{'autocreate'}): " . ($xml_config->{'autocreate'} ? "TRUE" : "FALSE") . "\n";
print "DB  if(config->{autocreate}): " . ($new_config->{autocreate} ? "TRUE" : "FALSE") . "\n";

# Test matchpoint
print "\nTesting matchpoint:\n";
print "XML matchpoint: " . $xml_config->{matchpoint} . "\n";
print "DB matchpoint: " . $new_config->{matchpoint} . "\n";
print "Match: " . ($xml_config->{matchpoint} eq $new_config->{matchpoint} ? "YES" : "NO") . "\n";

# Initialize mismatches array at the start
my @mismatches;

# Test mappings
print "\nTesting mappings:\n";
my @mapping_errors;
foreach my $field (sort keys %{$xml_config->{mapping}}) {
    my $xml_mapping = $xml_config->{mapping}->{$field}->{is} // '';
    my $db_mapping = $new_config->{mapping}->{$field}->{is} // '';
    
    print "$field:\n";
    print "  XML mapping: '" . ($xml_mapping || '<empty>') . "'\n";
    print "  DB mapping:  '" . ($db_mapping || '<empty>') . "'\n";
    print "  Match: " . ($xml_mapping eq $db_mapping ? "YES" : "NO") . "\n\n";
    
    if ($xml_mapping ne $db_mapping) {
        push @mapping_errors, sprintf(
            "Field '%s' has mismatched mappings - XML:'%s' DB:'%s'",
            $field,
            $xml_mapping,
            $db_mapping
        );
    }
}

# Add mapping errors to mismatches list
push @mismatches, @mapping_errors if @mapping_errors;

# Test value types and string comparison
print "\nTesting value types and comparison:\n";
foreach my $setting (qw(autocreate sync welcome)) {
    print "$setting check:\n";
    my $xml_val = defined $xml_config->{$setting} ? $xml_config->{$setting} : 'undef';
    my $db_val = defined $new_config->{$setting} ? $new_config->{$setting} : 'undef';
    
    print "  XML value: '$xml_val' (type: " . (ref($xml_config->{$setting}) || 'scalar/undef') . ")\n";
    print "  DB value: '$db_val' (type: " . (ref($new_config->{$setting}) || 'scalar/undef') . ")\n";
    
    # Test different comparison methods
    if (defined $xml_config->{$setting} && defined $new_config->{$setting}) {
        print "  Direct comparison (==): " . ($xml_config->{$setting} == $new_config->{$setting} ? "MATCH" : "NO MATCH") . "\n";
        print "  String comparison (eq): " . ($xml_config->{$setting} eq $new_config->{$setting} ? "MATCH" : "NO MATCH") . "\n";
    } else {
        print "  Direct comparison (==): SKIPPED - undefined value(s)\n";
        print "  String comparison (eq): SKIPPED - undefined value(s)\n";
    }
    
    print "  Boolean test XML: " . ($xml_config->{$setting} ? "TRUE" : "FALSE") . "\n";
    print "  Boolean test DB: " . ($new_config->{$setting} ? "TRUE" : "FALSE") . "\n";
    print "  XML in if: " . (defined $xml_config->{$setting} && $xml_config->{$setting} ? "TRUE" : "FALSE") . "\n";
    print "  DB in if: " . (defined $new_config->{$setting} && $new_config->{$setting} ? "TRUE" : "FALSE") . "\n\n";
}

# Add final summary of mismatches
print "\n=== COMPARISON SUMMARY ===\n";

# Check settings
foreach my $setting (qw(enable_opac_sso enable_staff_sso autocreate sync welcome)) {
    my $xml_val = $xml_config->{$setting} ? 1 : 0;
    my $db_val = $new_config->{$setting} ? 1 : 0;
    if ($xml_val != $db_val) {
        push @mismatches, "Setting '$setting' mismatch: XML=$xml_val DB=$db_val";
    }
}

# Check matchpoint
if ($xml_config->{matchpoint} ne $new_config->{matchpoint}) {
    push @mismatches, "Matchpoint mismatch: XML=" . $xml_config->{matchpoint} . 
                      " DB=" . $new_config->{matchpoint};
}

# Check mappings
foreach my $field (sort keys %{$xml_config->{mapping}}) {
    my $xml_mapping = $xml_config->{mapping}->{$field}->{is} // '';
    my $db_mapping = $new_config->{mapping}->{$field}->{is} // '';
    
    if ($xml_mapping ne $db_mapping) {
        push @mismatches, sprintf(
            "Mapping '%s' mismatch: XML='%s' DB='%s'",
            $field,
            $xml_mapping,
            $db_mapping
        );
    }
}

if (@mismatches) {
    print "ERRORS FOUND:\n";
    print "  $_\n" for @mismatches;
} else {
    print "All comparisons match successfully!\n";
}

# Cleanup
print "\nCleaning up test data...\n";
$mappings->delete;

print "\nDone!\n";
