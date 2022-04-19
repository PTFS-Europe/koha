#!/usr/bin/perl

use lib '/home/koha/kohaclone';
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

# Koha Imports
use C4::Context;    # Koha Database Access

my $showLink = C4::Context->preference('RequestOnOpac');
my $showARLink = C4::Context->preference('ArticleRequests');

my $rv = "{\"showlink\":\"$showLink\",\"showARLink\":\"$showARLink\"}";

print "Content-type: text/json\n\n";
print $rv;

exit;
