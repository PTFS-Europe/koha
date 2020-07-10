#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);
use XML::Simple;
use Data::Dumper;

# base url for our openURL resolver
my $baseURL = 'http://ud7ed2gm9k.search.serialssolutions.com/?';

# Address for 360 Link XML API
my $ssURL = 'http://ud7ed2gm9k.openurl.xml.serialssolutions.com/openurlxml';
my $ssVersionParam = "version=1.0";
$ssURL = $ssURL . "?" . $ssVersionParam;

my $q = new CGI;
my $xsl = XML::Simple->new();

my $jtitle = $q->param('jtitle');
my $volume = $q->param('volume');
my $issue = $q->param('issue');
my $theDate = $q->param('thedate');
my $atitle = $q->param('atitle');
my $author = $q->param('author');
my $pages = $q->param('pages');
my $barcode = $q->param('barcode');

my $res = &runQuery($ssURL,$jtitle,$theDate);
my $doc = $xsl->XMLin($res,forcearray=>1);
# my $doc = $xsl->XMLin($res);
my $structureDump = Dumper($doc);
$structureDump =~ s/\n/<br\/>/g;

#print "Content-type: text/html\n\n";
#print $structureDump;
#exit;

# retrieves ISSN when forceArray=1
# $doc->{'ssopenurl:results'}->[0]->{'ssopenurl:result'}->[0]->{'ssopenurl:citation'}->[0]->{'ssopenurl:issn'}->[0]->{'content'}
# retireves ISSN when forceArray is not included
# $doc->{'ssopenurl:results'}->{'ssopenurl:result'}->{'ssopenurl:citation'}->{'ssopenurl:issn'}->[0]->{'content'}

my $openURL;
my $issn;
my $linkURL;

my $message = "Not working";

# if this element exists then we do have access to the journal (according to 360 Link).
if (defined $doc->{'ssopenurl:results'}->[0]{'ssopenurl:result'}->[0]->{'ssopenurl:linkGroups'}->[0]) {
	$message = "WORKING!!";
	# build openURL
	# log the fact that we have found the title
	# example of URL: http://ud7ed2gm9k.scholar.serialssolutions.com/?sid=google&auinit=PA&aulast=David&atitle=Clio+and+the+Economics+of+QWERTY&title=American+economic+review&volume=75&issue=2&date=1985&spage=332&issn=0002-8282
	$issn = $doc->{'ssopenurl:results'}->[1]->{'ssopenurl:result'}->[0]->{'ssopenurl:citation'}->[0]->{'ssopenurl:issn'}->[0]->{'content'};
	$openURL = $baseURL;
	if(defined $issn) {
		$openURL = $openURL . "rft.issn=" . $issn;
	}
	if (defined $theDate) {
		# might have to do something with the date to get it into the correct format?
		$openURL = $openURL . "rft.date=" . $theDate;
	}
	if (defined $volume) {
		$openURL = $openURL . "rft.voulme=" . $volume;
	}
	if (defined $issue) {
		$openURL = $openURL . "rft.issue=" . $issue;
	}
	if (defined $pages) {
		my $spage;
		my $epage;
		# might have to do something with the pages number to split them and store in start page/end page
		if ($pages =~ m/-/) {
			($spage,$epage) = split("-",$pages);
		} else {
			$spage = $pages;
		}
		if (defined $spage) {
			$openURL = $openURL . "rft.spage=" . $spage;
		}
		if (defined $epage) {
			$openURL = $openURL . "rft.epage=" . $epage;
		}
	}
} else {
		# do we did to do anything if cannot find journal?
}

print "Content-type: text/html\n\n";

# get start date
# $doc->{'ssopenurl:results'}->{'ssopenurl:result'}->{'ssopenurl:linkGroups'}->{'ssopenurl:linkGroup'}->{'ssopenurl:holdingData'}->{'ssopenurl:normalizedData'}->{'ssopenurl:startDate'}

print<<ENDOFHTML

<html>

<head>
	<title>Serial Solutions 360 Link API Test</title>
	<style type="text/css">
		#perldump { border:2px solid; }
	</style>
</head>

<body>

$message - $linkURL

<table>
	<tr>
		<td><b>Title: </b></td>
		<td><b>$jtitle</b></td>
	</tr>
	<tr>
		<td><b>ISSN: </b></td>
		<td><b>$issn</b></td>
	</tr>
	<tr>
		<td><b>Start Date: </b></td>
		<td><b>$theDate</b></td>
	</tr>
</table>
<br/>

ENDOFHTML
;

if (defined $openURL) {
	print "Access full text of article <a href=\"$openURL\" target=\"_newwin\">here</a>";
}

print<<ENDOFHTML

<br/>
<br/>

<div id="perldump">
	<code>$structureDump</code>
</div>

</body></html>

ENDOFHTML
;

###################################

sub runQuery($$$) {
	my $ssURL = $_[0];
	my $jtitle = $_[1];
	my $theDate = $_[2];
	$jtitle =~ s/ /+/g; # sub spaces for plus signs
	if (! defined $theDate) {
		$ssURL = $ssURL . "\&rft.jtitle=" . $jtitle;
	} else {
		$ssURL = $ssURL . "\&rft.jtitle=" . $jtitle . "\&rft.date=" . $theDate;
	}
	my $data = `/usr/bin/curl -s -k "$ssURL"`;
	$linkURL = $ssURL;
	return $data;
}
