#!/usr/bin/perl

use lib '/home/koha/kohaclone';
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

# Koha Imports
use C4::Context;    # Koha Database Access

my $DEBUG = 0;
my $debugString;

my $q = new CGI;
my @ids;

if ($q->param('DEBUG')) {
	$DEBUG = 1;
}

my $bibIDString = $q->param('bibids');

$debugString .= "<br>The ID is $bibIDString<br>";

my $data = &getAvailability($bibIDString);

my $available = 0;
my $holdCount = 0;

my $showLink = 0;

foreach my $rec (@$data) {
	my ($availability,$numberOfHolds,$waiting) = @$rec;
	if ($availability == 'Available') {
		$available++;
	}
	# $holdCount = $numberOfHolds;
	$holdCount = $waiting;
}

$debugString .= "<br>There are $available available<br>\n";
$debugString .= "<br>The hold count is $holdCount <br>\n";

if ($available > 0) {
	if (($available - $holdCount) > 0) {
		$showLink = 0;
	} else {
		$showLink = 1;
	}
} else {
	$showLink = 1;
}

my $rv = "{\"showlink\":\"$showLink\"}";

$debugString .= "<br>JSON: <pre>$rv</pre><br>";

if ($DEBUG) {
	print "Content-type: text/html\n\n";
	print $debugString;
} else {
	print "Content-type: text/json\n\n";
	print $rv;
}

exit;

#######################################

sub getAvailability($) {

	my $bibID = $_[0];

    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;

	my $SQL = "select
				if(onloan is null,'Available','Checked Out') onloan,
				(select count(biblionumber) from reserves where biblionumber = '$bibID' and found is null) as holds,
				(select count(biblionumber) from reserves where biblionumber = '$bibID' and found = 'W') as waiting
				from items,authorised_values,branches
				where biblionumber = '$bibID'
				and authorised_values.category = 'LOC'
				and items.location = authorised_values.authorised_value
				and items.homebranch = branches.branchcode
				and lib != 'Missing'
				and itype not in ('REF','MIS')
				and notforloan = 'false'
				and onloan is null
				and itemlost = 'false'";

	$debugString .= "<br>The SQL is $SQL<br>";


	$sth = $dbh->prepare($SQL)
		or warn "Can't prepare $query: $dbh->errstr\n";
	$sth->execute()
          or warn "Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;
}

#######################################
