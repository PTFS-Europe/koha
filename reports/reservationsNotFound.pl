#!/usr/bin/perl -w

use lib '/home/koha/kohaclone';
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use CGI qw/:standard -debug/;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

# Koha Imports
use C4::Context;    # Koha Database Access
use C4::Auth;
use C4::Output;
use C4::Koha;

my $DEBUG = 0;
my $debugString;

my $CLSelfCheckUsers = "'69518','249650','249651'";
my $DHSelfCheckUsers = "'249652','249653','249654'";
my $campus;

my $q = new CGI;

my ($template, $borrowernumber, $cookie)
    = get_template_and_user(
      {
	template_name   => 'reports/reservationsNotFound.tt',
	query           => $q,
     	type            => "intranet",
      	flagsrequired   => { reports => '*' },
  }
);


my $lrc = $q->param('lrc');
chomp($lrc);

my $selfCheckUser;

if ($lrc eq "DH") {
	$selfCheckUser = $DHSelfCheckUsers;
	$campus = "de Hav LRC";
} else {
	$selfCheckUser = $CLSelfCheckUsers;
	$campus = "College Lane LRC";
}

my %bookHash;
my %numberOfReserveHash;

my $GETITEMNUMBERSSQL = "select info from action_logs where info in (
							select itemnumber from items where biblionumber in (
								select distinct(biblionumber) from reserves where found is null 
							) and onloan is null
						)
						and module = 'CIRCULATION' 
						and action = 'RETURN' 
						and user in ($selfCheckUser) 
						and timestamp > date(now() - interval 1 day)";
						
my $data = &getRecords($GETITEMNUMBERSSQL);

my $listOfIDs = '';

# iterate over the IDs and if they haven't already been satisfied
# then create a formatted list to add to the next SQL statement.
foreach my $rec (@$data) {
	my ($id) = @$rec;
	print "The ID is $id\n" if $DEBUG;
	# we are not interested in item IDs which have been satisfied
	# my $CHECKSATISFIEDSQL = "select count($id) from reserves where itemnumber = '$id'";
	my $CHECKSATISFIEDSQL = "select count(*) from reserves where itemnumber = '$id' and (found is null or found = 'W')";
	my $satisfied = &getRecords($CHECKSATISFIEDSQL);
	print "SATISFIED: " . $$satisfied[0][0] . "\n" if $DEBUG;
	if ($$satisfied[0][0] == 0) {
		$listOfIDs .= "'$id',";
	}
}
chop $listOfIDs;
print "The list of IDS is " . $listOfIDs . "\n\n\n" if $DEBUG;

my %indReserveDetails;

if ($listOfIDs) {

	my $GETITEMDETAILSSQL = "select i.biblionumber, b.title, i.itemcallnumber, bi.isbn from items i, biblio b, biblioitems bi where i.itemnumber in ($listOfIDs) and i.biblionumber = b.biblionumber and i.biblionumber = bi.biblionumber";

	my $items = &getRecords($GETITEMDETAILSSQL);
	
	foreach my $rec (@$items) {
		my ($bibID,$title,$call,$isbn) = @$rec;
		print "Adding $bibID to indReserveDetails hash\n" if $DEBUG;
		$indReserveDetails{$bibID} = $rec;
		if ($DEBUG) {
			print "The bib ID is " . $bibID . "\n";
			print "The title is " . $title . "\n";
			print "The call number is " . $call . "\n";
			print "The ISBN is " . $isbn . "\n";
		}
		if (exists $bookHash{$bibID}) {
			print $bookHash{$bibID} . " exists, so incrementing by one\n" if $DEBUG;
			$bookHash{$bibID}++;
		} else {
			print "Setting $bibID to one\n" if $DEBUG;
			$bookHash{$bibID} = 1;
			my $GETRESERVESQL = "select count(*) from reserves where biblionumber = '$bibID' and found is null";
			my $numberOfReserves = &getRecords($GETRESERVESQL);
			print "The number of reservations is " . $$numberOfReserves[0][0]. "\n" if $DEBUG;
			$numberOfReserveHash{$bibID} = $$numberOfReserves[0][0];
			#print Dumper($numberOfReserves);

		}
		print "\n\n" if $DEBUG;
	}
} else {
	print "There are no IDs\n" if $DEBUG;
}

my $html;

print "Number of items available to fulfil reservations\tNumber of unfulfilled reservations\tTitle\tISBN\tCall Number\n" if $DEBUG;

foreach my $key (keys %indReserveDetails) {
	print "THE KEY IS $key\n" if $DEBUG;
	print $bookHash{$key} . "\t" . $numberOfReserveHash{$key} . "\t" if $DEBUG;
	$html .= "<tr><td>" . $bookHash{$key} . "</td><td>" . $numberOfReserveHash{$key} . "</td>";
	my $rec = $indReserveDetails{$key};
	my ($bibID,$title,$call,$isbn) = @$rec;
	print $title . "\t" . $isbn . "\t" . $call . "\n" if $DEBUG;
	$html .= "<td><a href=\"/cgi-bin/koha/catalogue/detail.pl?biblionumber=$bibID\">" . $title . "</a></td><td>" . $isbn . "</td><td>" . $call . "</td></tr>\n";
}

if ($DEBUG) {
	foreach my $key (keys %bookHash) {
		print $key . " - " . $bookHash{$key} . "\n";
	}
}

$template->param(
          requestBody => $html,
	campus => $campus,
);

output_html_with_http_headers($q, $cookie, $template->output);

exit;


exit;

########################################

sub getRecords($) {

	my $SQL = $_[0];

	my $dbh = C4::Context->dbh;
    	my $query;
    	my $sth;

	$sth = $dbh->prepare($SQL)
		or warn "Can't prepare $query: $dbh->errstr\n";
	$sth->execute()
          or warn "Can't execute the query: $sth->errstr\n";
    
	my $data = $sth->fetchall_arrayref();
	
	return $data;
}

###########################################
