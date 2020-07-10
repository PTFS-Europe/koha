#!/usr/bin/perl -w

use CGI qw/:standard -debug/;
use LWP::UserAgent;
use HTTP::Request;
use XML::LibXML;
use Data::Dumper;
use JSON;

use C4::Auth;
# use C4::Auth_with_shibboleth;

my $DEBUG = 0;

my $q = new CGI;
my $userBarcode = $q->param('barcode');
chomp($userBarcode);

my ( $user, $cookie, $sessionID, $flags ) = checkauth( $q, 0, {}, 'opac' );
#my $shib_login = get_login_shib();
#my ( $retval, $userBarcode, $userID ) = checkpw_shib( $shib_login );

my $serviceBaseURL = 'https://library.herts.ac.uk/cgi-bin/koha/ilsdi.pl';

my $apiURL = &getLookupPatronURL($userBarcode,$serviceBaseURL);
my $response = &webCall($apiURL);

my $json;

if ($response !~ m/^ERROR/) {
	my $kohaID = &parseLookupResponse($response);
	print "The Koha ID is $kohaID\n" if $DEBUG;
	my $userInfoURL = &getPatronInformationURL($kohaID,$serviceBaseURL);
	my $res = &webCall($userInfoURL);
	$json = &parseXML($res);
 }
 else {
	# create JSON with error in
}

print $q->header(
	-type => 'application/json'
);
#print "Content-type: application/json\n\n";
print $json;

exit;

#################################

sub getLookupPatronURL($$) {

	my $barcode = $_[0];
	my $baseURL = $_[1];
	my $returnURL = $baseURL . "?service=LookupPatron&id=" . $barcode . "&id_type=cardnumber";
	print "The LookupPatron url is $returnURL\n" if $DEBUG;
	return $returnURL;
}

#################################

sub parseLookupResponse($) {

	my $response = $_[0];
	$response =~ m/<id>(.*)<\/id>/;
	my $kohaUserID = $1; # need to check for error here
	return $kohaUserID;
}

##################################

sub getPatronInformationURL($$) {

	my $kuid = $_[0];
	my $baseURL = $_[1];
	my $returnURL = $baseURL . "?service=GetPatronInfo&patron_id=" . $kuid . "&show_contact=0&show_loans=1";
	print "The GetPatronInfo url is $returnURL\n" if $DEBUG;
	return $returnURL;
}

##################################

sub webCall($) {

	my $apiURL = $_[0];
	my $ua = LWP::UserAgent->new;
	my $request = HTTP::Request->new("GET",$apiURL);
	print $request->as_string if $DEBUG;
	my $response = $ua->request($request);

	my $returnVal;

	if ($response->is_success) {
		print $response->decoded_content if $DEBUG; # or whatever
		$returnVal = $response->decoded_content;
	}	else {
		print $response->decoded_content if $DEBUG;
		# die $response->status_line;
		$returnVal = "ERROR: " . $response->status_line;
	}

	return $returnVal;;
}

###################################

sub parseXML($) {

	my @loans;
	$xmlData = $_[0];
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_string($xmlData);
	foreach my $loan ($doc->findnodes('/GetPatronInfo/loans/loan')) {

		$hashRef{"title"} = $loan->findvalue('./title');
		$hashRef{"datedue"} = $loan->findvalue('./date_due');
		if ($loan->findvalue('./overdue')) {
			$hashRef{"overdue"} = $loan->findvalue('./overdue');
		} else {
			$hashRef{"overdue"} = "0";
		}
		$hashRef{"totalrenewals"} = $loan->findvalue('./totalrenewals');

		push @loans, { %hashRef };
		%hashRef = ();
	}

	if ($DEBUG) {
		my $count = 1;
		foreach my $loan (@loans) {
			print Dumper($loan);
			print "Loan $count : ";
			foreach my $key (keys %$loan) {
				print $key . " : " . ${$loan}{$key} . "\n";
			}
			$count++;
		}
	}

	my $json_text = JSON->new->utf8->encode(\@loans);
	#my $JSON = JSON->new->utf8;
	#$JSON->allow_blessed(1);
	#my $json_text = $JSON->encode(\@loans);
	#print $json_text if $DEBUG;
	return $json_text;
}
