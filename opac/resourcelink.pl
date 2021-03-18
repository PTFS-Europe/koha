#!/usr/bin/perl

use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);
use XML::Simple;
use Data::Dumper;

my $q = new CGI;
my $xsl = XML::Simple->new();

# example URL
# https://library.herts.ac.uk/cgi-bin/koha/oai.pl?verb=GetRecord&identifier=KOHA-OAI-HERT:300864&metadataPrefix=oai_dc

my $bibID = $q->param('biblionumber');
my $kurl = 'https://library.herts.ac.uk/cgi-bin/koha/oai.pl?verb=GetRecord&identifier=KOHA-OAI-HERT:' . $bibID . '&metadataPrefix=oai_dc';

# print "Content-type: text/html\n\n";
#print "The URL is $kurl\n";

my $responseXML = `/usr/bin/curl -s "$kurl"`;

my $doc = $xsl->XMLin($responseXML,forcearray=>1);

#my $structureDump = Dumper($doc);
#$structureDump =~ s/\n/<br\/>/g;
#print $structureDump;

my $redirectURL;
my $serviceURLs = $doc->{'GetRecord'}->[0]->{'record'}->[0]->{'metadata'}->[0]->{'oai_dc:dc'}->[0]->{'dc:identifier'};
# print "The URL to direct to is " . $serviceURL;
foreach my $su (@{$serviceURLs}) {
	next if ($su =~ m/^URN/ || $su =~ m/studynet/);
	# print "The URL is $su . <br/>\n";
	$redirectURL = $su;
}

 print $q->redirect($redirectURL);

#print "Content-type: text/xml\n\n";
#print $responseXML;
#exit;
