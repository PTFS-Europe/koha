#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

my $q = new CGI;

#my $reportID = $q->param('id');
#my $params  = $q->param('sql_params');
my $URL = $q->param('URL');

# my $kURL = 'https://library.herts.ac.uk/cgi-bin/koha/svc/report?id=' . $reportID . '&sql_params=' . $params;

my $json = `/usr/bin/curl -s "$URL"`;

print "Content-type: application/json\n\n";
print $json;
exit;
