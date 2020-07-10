#!/usr/bin/perl

use lib '/home/koha/kohaclone';
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
# use CGI qw/:standard -debug/;
use CGI qw/:standard/;
# use CGI::Carp qw(fatalsToBrowser);

# Koha Imports
use C4::Context;    # Koha Database Access

my $DEBUG = 0;
my $debugString;

my $q = new CGI;
my @ids;

if ($q->param('DEBUG')) {
	$DEBUG = 1;
}

if ($q->param('bibids') =~ m/:/) {
	@ids = split(/:/,$q->param('bibids'));
} else {
	push @ids,$q->param('bibids');
}

my $bibIDString;

if ($#ids == 0) {
	$bibIDString = "'$ids[0]'";
} else {
	foreach my $id (@ids) {
		$bibIDString .= "'$id',";
	}
	chop($bibIDString);
}

$debugString .= "<br>There are " . ++$#ids . " bibIDs, which are $bibIDString<br>";

my $data = &getAvailability($bibIDString);


my $xml = "<?xml version=\"1.0\" ?>\n<holdings>\n";

my $idcheck = "1";

my $xmlody;

foreach my $rec (@$data) {
	my ($id,$loc,$callnumber,$availabilty) = @$rec;
	$loc =~ s/Learning Resources Centre/LRC/;
	if ($idcheck != $id) {
		$idcheck = $id;
		$xmlbody .= "</bibrecord>\n";
		$xmlbody .= "<bibrecord>\n";
		$xmlbody .= "<item>$id</item>\n";
	}

	$xmlbody .= "<itemdetails>\n";
	$xmlbody .= "<status>$availabilty</status>\n";
	$xmlbody .= "<location>$loc</location>\n";
	$xmlbody .= "<callnumber>$callnumber</callnumber>\n";
	$xmlbody .= "</itemdetails>\n";
}

$xmlbody =~ s/^<\/bibrecord>\n//;

$xml .= $xmlbody . "</bibrecord>\n</holdings>";

$debugString .= "<br>JSON: <pre>$rv</pre><br>";

if ($DEBUG) {
	print "Content-type: text/html\n\n";
	print $debugString;
} else {
	binmode STDOUT, ":utf8";
	print "Content-type: text/xml\n\n";
	print $xml;
}

exit;

#######################################

sub getAvailability($) {

	my $bibIDs = $_[0];

    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;

	my $SQL = "select
				biblionumber,
				concat (branchname, ', ', lib) as location,
				itemcallnumber,
				if(onloan is null,'Available','Checked Out') onloan
				from items,authorised_values,branches
				where biblionumber in ($bibIDs)
				and authorised_values.category = 'LOC'
				and items.location = authorised_values.authorised_value
				and items.homebranch = branches.branchcode";

	$debugString .= "<br>The SQL is $SQL<br>";

	$sth = $dbh->prepare($SQL)
		or warn "Can't prepare $query: $dbh->errstr\n";
	$sth->execute()
          or warn "Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;
}

#######################################
