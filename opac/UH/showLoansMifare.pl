#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use Data::Dumper;
use JSON;
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use MIME::Base64;

use C4::Context;    # Koha Database Access

my $DEBUG = 0;

my %allowedIPs = (
	"147.197.138.27" => "GLJ Server"
);

my $reqIP = $ENV{"REMOTE_ADDR"};

if (! exists $allowedIPs{$reqIP}) {
	print "Content-type: text/html\n\n";
        print "Out of range\n";
	exit;
}

my $q = new CGI;
my $userBarcode = $q->param('barcode');
chomp($userBarcode);

if ($userBarcode !~ /^044/) {
	$userBarcode = decode_base64($userBarcode);
}

my $data = &getData($userBarcode);
# print Dumper($data);
my $json = &parseData($data);

print $q->header(
	-type => 'application/json'
);
print $json;

exit;

###################################

sub parseData($) {

	my $data = $_[0];
	my @loans;

	foreach my $rec (@$data) {
		my ($bibID,$onHold,$numberOfRenewals,$title,$overdue,$returnDate,$maxRenewals) = @$rec;

		if ($onHold > 0) {
			$onHold = 1;
		}

		$hashRef{"title"} = $title;
		$hashRef{"datedue"} = $returnDate;
		$hashRef{"biblionumber"} = $bibID;
		$hashRef{"overdue"} = $overdue;
		$hashRef{"totalrenewals"} = $numberOfRenewals;
		$hashRef{"hold"} = $onHold;
		$hashRef{"maxRenewals"} = $maxRenewals;
		push @loans, { %hashRef };
		%hashRef = ();
	}

	my $json_text = JSON->new->utf8->encode(\@loans);

	#my $JSON = JSON->new->utf8;
	#$JSON->allow_blessed(1);
	#my $json_text = $JSON->encode(\@loans);
	#print $json_text if $DEBUG;
	return $json_text;
}

##########################################

sub getData($) {

	my $barcode = $_[0];

	my $dbh = C4::Context->dbh;
    my $query;
    my $sth;

	#my $SQL = "select bi.biblionumber,
	#			(select count(*) from reserves r where r.biblionumber = bi.biblionumber),
	#			i.renewals,
	#			SUBSTRING_INDEX(ExtractValue(bm.metadata,'//datafield[\@tag=\"245\"]/subfield[\@code>=\"a\"]'),'/','1'),
	#			if (curdate() > i.date_due,1,0),
	#			date(i.date_due)
	#			from issues i, biblioitems bi, items it, biblio_metadata bm
	#			where i.borrowernumber = (select borrowernumber from borrowers where (cardnumber = '". $barcode . "' or userid = '". $barcode . "')) 
	#			and i.itemnumber = it.itemnumber
	#			and bm.biblionumber = bi.biblionumber
	#			and it.biblioitemnumber = bi.biblioitemnumber
	#";

	my $SQL = "select bi.biblionumber,
       			(select count(*) from reserves r where r.biblionumber = bi.biblionumber),
       			i.renewals,
			SUBSTRING_INDEX(ExtractValue(bm.metadata,'//datafield[\@tag=\"245\"]/subfield[\@code>=\"a\"]'),'/','1'),
       			if (curdate() > i.date_due,1,0),
       			date(i.date_due),
       			if(b.categorycode = 'UHSTU','10','26') maxRenewals
			from issues i, biblioitems bi, items it, biblio_metadata bm, borrowers b, borrower_attributes ba
			where i.borrowernumber = b.borrowernumber
			and ba.code = 'UHBC'
			and ba.attribute = '" . $barcode .  "'
			and b.borrowernumber = ba.borrowernumber
			and i.itemnumber = it.itemnumber
			and bm.biblionumber = bi.biblionumber
			and it.biblioitemnumber = bi.biblioitemnumber
	";

	# print "checkHolds sub: The SQL is $SQL";

	$sth = $dbh->prepare($SQL)
		or warn "Can't prepare $query: $dbh->errstr\n";
	$sth->execute()
          or warn "Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;
}
