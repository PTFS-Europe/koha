#!/usr/bin/perl

use lib '/home/koha/kohaclone';
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);

# Koha Imports
use C4::Context;    # Koha Database Access

my $DEBUG = 0;
my $MAXREQUESTS = 5;
my $debugString;

my $q = new CGI;
# my @ids;

my $ua = $ENV{"HTTP_USER_AGENT"};

my %jsonHash;

if ($q->param('DEBUG')) {
	$DEBUG = 1;
}

my $bibIDString = $q->param('bibid');
my $userID = $q->param('userid');
my $type = $q->param('type');

$debugString .= "<br>SG The ID is $bibIDString<br>";
$debugString .= "<br>The User ID is $userID<br>";
$debugString .= "<br>The Item Type is $type<br>";

my $refCount = 0;

if ($userID eq "NOUID") {
	$refCount = &checkOnShelf($bibIDString);
	if ($refCount > 0) {	
		$jsonHash{"Allowed"} = 2; 
		$jsonHash{"Reason"} = "Need to Login";	
	} else {
		$jsonHash{"Allowed"} = 3; 
		$jsonHash{"Reason"} = "Show nothing";	
	}
} else {

	# only need to check for books/chapters
	if ($type =~ /chapter/) {
		# check that there is a reference copy
		# $refCount = &checkForRefCopy($bibIDString);
		$refCount = &checkOnShelf($bibIDString);
	} else {
		$refCount = 1;
	}

	$debugString .= "<br>There are $refCount reference copies<br>\n";

	if ($refCount > 0) {

		my $reqCount = 1;

		# only need to check for books
		if ($type =~ /chapter/) {
			$reqCount = &getPlacedBefore($bibIDString,$userID);
		} else {
			$reqCount = 0;
		}

		if ($reqCount > 0) {
			# this means that the user has already placed a request for this book
			$jsonHash{"Allowed"} = 0;
			$jsonHash{"Reason"} = "You have already placed a request from this book";
		} else {
			# the user is allowed but let's check to see if they have more than 5 open request
			my $currentReq = &getCurrentRequestCount($userID);
			if ($currentReq >= $MAXREQUESTS) {
				$jsonHash{"Allowed"} = 0;
				$jsonHash{"Reason"} = "You have the maximum number of  requests: " . $MAXREQUESTS;
			} else {
				$jsonHash{"Allowed"} = 1; 
				$jsonHash{"Reason"} = "OK ALL";	
			}
		}
	} else {
		$jsonHash{"Allowed"} = 0;
		$jsonHash{"Reason"} = "No copies available on shelf";

	}
}

if ($ua =~ m/Trident/) {
	$jsonHash{"Allowed"} = 0;
	$jsonHash{"Reason"} = "Unsupported browser. Please use a more modern browser.";
}

#my $rv = "[{\"Allowed\":" . $jsonHash{"Allowed"} . ",\"Reason\":\"" . $jsonHash{"Reason"} . "\"}]";
my $rv = "{\"Allowed\":" . $jsonHash{"Allowed"} . ",\"Reason\":\"" . $jsonHash{"Reason"} . "\"}";

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

sub getPlacedBefore($$) {

    my $bibID = $_[0];
    my $userID = $_[1];

    my $dbh = C4::Context->dbh;
    my $query;

    my $SQL = "select count(id) from article_requests where borrowernumber = '" . $userID  . "' and biblionumber = '" . $bibID . "' and status != 'CANCELED';";

    $debugString .= "<br>The SQL is $SQL<br>";

    my $count = $dbh->selectrow_array($SQL);

   return $count;;
}

#######################################

sub getCurrentRequestCount($) {

    my $userID = $_[0];

    my $dbh = C4::Context->dbh;
    my $query;

    my $SQL = "select count(id) as amount from article_requests where  borrowernumber = '" . $userID  . "' and status not in ('COMPLETED','CANCELED');";

    $debugString .= "<br>The SQL is $SQL<br>";

    my $count = $dbh->selectrow_array($SQL);

    return $count;
}

#######################################
#
sub checkForRefCopy($) {

    my $bibID = $_[0];

    my $dbh = C4::Context->dbh;
    my $query;

    my $SQL = "select count(itemnumber) from items where biblionumber = '" . $bibID . "' and itype = 'REF';";

    $debugString .= "<br>The SQL is $SQL<br>";

    my $count = $dbh->selectrow_array($SQL);

   return $count;
}

########################################
#
sub checkOnShelf($) {

    my $bibID = $_[0];

    my $dbh = C4::Context->dbh;
    my $query;

    my $SQL = "select count(itemnumber) from items where biblionumber = '" . $bibID . "' and itype != 'MIS' and onloan is null and location = 'B' and itemlost = 'false';";

    $debugString .= "<br>The SQL is $SQL<br>";

    my $count = $dbh->selectrow_array($SQL);

   return $count;
}
