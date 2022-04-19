#!/usr/bin/perl

use Modern::Perl;

# modules we want to use
use DBI;           # Connect to DB
use DBD::mysql;    # Manipulate MySQL
use CGI;
# use CGI::Carp qw(fatalsToBrowser);
use Mail::Sendmail;
use Encode;

# Koha Imports
use C4::Context;    # Koha Database Access
use C4::Auth;
use C4::Output;
use C4::Koha;

use Koha::Illrequests;

# change to 1 (one) to view debug message
our $debug = 0;
our $SGTEST = 0;
our $sendToBL = 1;
our $update = 1;

# for my testing = turn into CGI param?
if ($SGTEST) { $sendToBL = 0; }

# UH email
our @blILLEmail;
our @localEmails;
our $uhILLEmail = "ill\@herts.ac.uk";
if ($sendToBL) {
	#print "Sending the request to the BL\n" if $debug;
	@blILLEmail = ("s.graham4\@herts.ac.uk","artemail\@art.bl.uk","ill\@herts.ac.uk");
	#@localEmails = ("s.graham4\@herts.ac.uk","d.m.peacock\@herts.ac.uk");
	@localEmails = ("s.graham4\@herts.ac.uk","ill\@herts.ac.uk");
} else {
	if ($SGTEST) {
		#print "Just sending requests to SG\n" if $debug;
		@blILLEmail = ("s.graham4\@herts.ac.uk");
		@localEmails = ("s.graham4\@herts.ac.uk");
	} else {
		#print "Just sending requests to ILL Admins\n" if $debug;
		@blILLEmail = ("s.graham4\@herts.ac.uk",$uhILLEmail);
		@localEmails = ("s.graham4\@herts.ac.uk",$uhILLEmail);
	}
}

# BL details - should go in an external file or mysql DB
our $artEmailLogin = "87-2236";
our $artEmailPwd = "yvymjmg";
our $artEmailPrefix = "TX";
our $UHReqPrefix = "UH-";
our $recordSep = "\n\n\n\n";
our $endOfRequest = "NNNN\n";
our $sedMessage = ":DELIVER ABOVE ITEM TO:\n";

our $emailBody = $artEmailLogin . "\n" . $artEmailPwd . "\n" . $recordSep;
our $illAdminEmailBody = "The following ILL requests have been sent via artemail:\n\n";
our $htmlBody;

our @updateIDs = ();

# increments by one every time there is a request
our $requestCount = 0;

# if this ever gets any higher than zero then a problem email is sent
our $requestProblem = 0;

# variable to store any problem requests we have
our $problemEmailText = "There has been a problem requesting the following request(s) from the BL. It looks like we cannot identify if this is a book or article request. Please investigate:\n\n";

##################################################
our $input = CGI->new;

my ($template, $borrowernumber, $cookie)
    = get_template_and_user(
      {
	template_name   => 'ill/ill-artemail.tt',
	query           => $input,
	type            => "intranet",
	flagsrequired   => { ill => '*' },
  }
);

# get the new requests
my $newILLRequests = &getNewILLRequests();

foreach my $records (@$newILLRequests) {
		my ($illID,$bNumber, $email, $reqType) = @$records;

		print "ILL number is " . $illID . "\n" if $debug;

		# look up the user details for ILL admin email
		my $borrowerInfo = &getBorrowerInfo($bNumber);
		$illAdminEmailBody .= "Barcode: " . @$borrowerInfo[0]->[0] . "\n";
		$illAdminEmailBody .= "User: " . @$borrowerInfo[0]->[2] . " " . @$borrowerInfo[0]->[1] . "\n";
		$illAdminEmailBody .= "Email: " . @$borrowerInfo[0]->[3] . "\n";

		$htmlBody .= "<b>Barcode:</b> " . @$borrowerInfo[0]->[0] . "<br>\n";
		$htmlBody .= "<b>User:</b> " . @$borrowerInfo[0]->[2] . " " . @$borrowerInfo[0]->[1] . "<br>\n";
		$htmlBody .= "<b>Email:</b> " . @$borrowerInfo[0]->[3] . "<br>\n";

		# retrieve the individual request
		my $indRecord = &lookupIndRecord($illID);

		my $recordProcessed = 0;
		$requestCount++;

		foreach my $record (@$indRecord) {
				my ($recID,$type,$value,$ro) = @$record;

				#print "$recID | $type | $value \n";

				if ($type eq "type") {

					print "The type is $type and the value is $value\n" if $debug;

					if ($value =~ m/article/i) {
							print "It's an Article\n" if $debug;
							$recordProcessed = 1;
							$emailBody .= &processArticle($indRecord,$recID,$email);
					} elsif ($value =~ m/journal/i) {
							print "It's a Journal\n" if $debug;
							$recordProcessed = 1;
							$emailBody .= &processJournal($indRecord,$recID,$email);
					} elsif  ($value =~ m/book/i) {
							$recordProcessed  = 1;
							print "It's a book\n" if $debug;
							$emailBody .= &processBook($indRecord,$recID);
					} elsif  ($value =~ m/Thesis/i) {
							$recordProcessed  = 1;
							print "It's a thesis\n" if $debug;
							$emailBody .= &processBook($indRecord,$recID);
					} elsif  ($value =~ m/Chapter/i) {
							print "It's a chapter\n" if $debug;
							$recordProcessed = 1;
							$emailBody .= &processChapter($indRecord,$recID,$email);
					} else {
						# OK - we haven't be able to determine the type, so let's have a guess
						# check for ISBN - it's a book
						# check for ISSN -  it's a article/journal
						# check for Issue/volume - it's an article/journals

						print "There is no type for $recID, let's try and find out what this request is.....\n" if $debug;
						# $htmlBody .= "There is no type for $recID, let's try and find out what this request is.....</br>";

						foreach my $r (@$indRecord) {

							my ($rID,$t,$v) = @$r;

							if (($t eq "isbn") && ($v ne "")) {
								$recordProcessed  = 1;
								print "It's a book\n" if $debug;
								$emailBody .= &processBook($indRecord,$rID);
							}

							if (($t eq "issn") && ($v ne "")) {
								print "It's an Article\n" if $debug;
								$recordProcessed = 1;
								$emailBody .= &processArticle($indRecord,$rID,$email);
							}

							if ((($t eq "issue") && ($v ne "")) ||  (($t eq "volume") && ($v ne "")) ) {
								print "It's an Article\n" if $debug;
								$recordProcessed = 1;
								$emailBody .= &processArticle($indRecord,$rID,$email);
							}

							last if ($recordProcessed);
						}

						# the record hasn't been processed because we haven't been able to determine the type
						# we need to report this.....
						if (!$recordProcessed) {
							$requestProblem++;
							$illAdminEmailBody .= "No Request information for user - see problem email\n\n";
							$problemEmailText .= "ILL Request Number: " . $UHReqPrefix . $recID . "\n";
							$problemEmailText .= "Barcode: " . @$borrowerInfo[0]->[0] . "\n";
							$problemEmailText .= "User: " . @$borrowerInfo[0]->[2] . " " . @$borrowerInfo[0]->[1] . "\n";
							$problemEmailText .= "Email: " . @$borrowerInfo[0]->[3] . "\n\n";
						}
					}
				}
			last if ($recordProcessed);
		}
		if ($recordProcessed) {
			#$htmlBody .= "Pushing $illID into array<br>\n";
			push(@updateIDs,$illID);
		}
}

$emailBody .= $endOfRequest;

print $emailBody if $debug;

# Of course we only want to send to BL if there are any requests
if ($requestCount > 0) {
	&emailBL($emailBody);
	&emailILLAdmin($illAdminEmailBody);
	$htmlBody = "<h3>The following ILL requests have been sent via artemail.</h3>" . $htmlBody;

	if ($update) {
		foreach my $kohaID (@updateIDs) {
			&updateStatus($kohaID);
		}
	}

} else {
	$illAdminEmailBody = "No ILL requests today.\n";
	&emailILLAdmin($illAdminEmailBody);
	$htmlBody = "<b>There are currently no ILL requests to send to the BL via ArtEmail</b>";
}

# if any problem requests then send email
if ($requestProblem > 0) {
	&emailProblemRequests($problemEmailText);
}

$template->param(
	  requestBody => $htmlBody,
);

# print "Content-type: text/html\n\n";
output_html_with_http_headers($input, $cookie, $template->output);

exit;

#################################################

sub getNewILLRequests {

	my $dbh = C4::Context->dbh;
	my $sth;

	#my $SQL = "select ir.id, ir.borrowernumber, b.email, ir.reqtype from ill_requests ir, borrowers b where ir.status = 'NEW' and ir.borrowernumber = b.borrowernumber";
	#my $SQL = "select ir.illrequest_id, ir.borrowernumber, b.email, ir.medium from illrequests ir, borrowers b where ir.status = 'NEW' and ir.backend = 'FreeForm' and ir.borrowernumber = b.borrowernumber";
	#my $SQL = "select ir.illrequest_id, ir.borrowernumber, b.email, ir.medium from illrequests ir, borrowers b where ((ir.status = 'NEW' and ir.status_alias is NULL) or (ir.status = 'REQ' and ir.status_alias = '465')) and ir.borrowernumber = b.borrowernumber";
	my $SQL = "select ir.illrequest_id, ir.borrowernumber, b.email, ir.medium from illrequests ir, borrowers b where ((ir.status = 'NEW' and ir.status_alias is NULL) or (ir.status = 'REQ' and ir.status_alias = 'NEW') or (ir.status = 'NEW' and ir.status_alias = 'NEW')) and ir.borrowernumber = b.borrowernumber";
	
	$sth = $dbh->prepare($SQL)
		or warn "getNewILLRequests sub: Can't prepare query: $dbh->errstr\n";

	$sth->execute()
          or warn "getNewILLRequests sub: Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;

}

#################################################

sub lookupIndRecord($) {

	my $reqID = $_[0];

	my $dbh = C4::Context->dbh;
	my $sth;

	my $SQL = "select * from illrequestattributes where illrequest_id = '" . $reqID . "'";

	$sth = $dbh->prepare($SQL)
		or warn "lookupIndRecord sub: Can't prepare query: $dbh->errstr\n";

	$sth->execute()
          or warn "lookupIndRecord sub: Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;

}

#################################################

sub getBorrowerInfo($) {

	my $bNumber = $_[0];

	my $dbh = C4::Context->dbh;
	my $sth;

	my $SQL = "select cardnumber, surname, firstname, email from borrowers where borrowernumber = '" . $bNumber . "'";

	$sth = $dbh->prepare($SQL)
		or warn "getBorrowerInfo sub: Can't prepare query: $dbh->errstr\n";

	$sth->execute()
          or warn "getBorrowerInfo sub: Can't execute the query: $sth->errstr\n";

	my $data = $sth->fetchall_arrayref();

	return $data;

}

#################################################

sub processArticle($$$$) {

	my $indRecord = $_[0];
	my $recID = $_[1];
	my $email = $_[2];

	#$htmlBody .= "Processing article $recID</br>";

	#my $req = $artEmailPrefix . $UHReqPrefix . $recID . " S SED99\n";
	my $req = $artEmailPrefix . $UHReqPrefix . $recID . " S PTW\n";

	my ($journalTitle,$year,$vol,$issue,$pages,$articleTitle,$author,$issn);

	# if we cannot fins the container_title, then we we'll fall back to using this
	my $backupJournalTitle;
	my $backupArticleTitle;

	foreach my $record (@$indRecord) {
		my ($recID,$type,$value) = @$record;
		#if ($type eq "title") {
		$value =~ s/^\s{1,}//;
		if ($type eq "container_title") {
			if ($value eq "") {
				$journalTitle = "No Journal Title Supplied";
				$backupJournalTitle = "No Journal Title Supplied";
			} else {
				$journalTitle = substr $value, 0, 40;
				$backupJournalTitle = substr $value, 0, 40;
			}
		}

		if ($type =~ m/\.\/metadata\/itemOfInterestLevel\/title/) {
			if ($value eq "") {
				$articleTitle = "No article Title Supplied";
				$backupArticleTitle = "No article Title Supplied";
			} else {
				$articleTitle = substr $value, 0, 40;
				$backupArticleTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "title") {
			if ($value eq "") {
				$backupJournalTitle = "No Journal Title Supplied";
			} else {
				$backupJournalTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "year") {
			$year = $value;
		}

		if ($type eq "volume") {
			if ($value ne "") {
				$vol = "VOL " . $value;
			}
		}

		if ($type eq "part_edition") {
			if ($value ne "") {
				$issue = "PT " . $value;
			}
		}

		if ($type eq "article_pages") {
			if ($value ne "") {
				$pages = "PP " . $value;
			}
		}

		if ($type eq "article_title") {
			if ($value eq "") {
				$articleTitle = "No Article Title Supplied";
			} else {
				$articleTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "article_author") {
			if ($value ne "") {
				$author = substr $value, 0, 40;
				$author .= "\n";
			}
		}

		if ($type eq "issn") {
			if ($value ne "") {
				$issn = $value . "\n";
			}
		}
	}

	if ($articleTitle eq "") {
		$articleTitle = "No article title supplied";
	}

	if ($journalTitle eq "") {
		$journalTitle = $backupJournalTitle;
	}
	
	$illAdminEmailBody .= $UHReqPrefix . $recID . "\n";
	$illAdminEmailBody .= $articleTitle . "\n\n";

	$htmlBody .= $UHReqPrefix . $recID . "<br>\n";
	$htmlBody .= $articleTitle . "<br><br>\n\n";

	my $dateIssueInfo = $year . " " . $vol . " " . $issue . " " . $pages;

	if ($dateIssueInfo !~ m/[a-z,A-Z,0-9]/) {
		$dateIssueInfo = "No date,volume,issue number supplied";
	}

	$req .= $journalTitle . "\n" . $dateIssueInfo . "\n" . $articleTitle . "\n" . $author . $issn . $recordSep . $sedMessage . $email . "\n" . $recordSep;

	print "Article Request:\n" . $req . "\n" if $debug;

	return $req;
}

####################################

sub processChapter($$$) {

	my $indRecord = $_[0];
	my $recID = $_[1];
	my $email = $_[2];

	#$htmlBody .= "Processing article $recID</br>";

	#my $req = $artEmailPrefix . $UHReqPrefix . $recID . " S SED99\n";
	my $req = $artEmailPrefix . $UHReqPrefix . $recID . " S PTW\n";

	my ($bookTitle,$year,$vol,$issue,$pages,$chapterTitle,$author,$isbn);

	# if we cannot find the container_title, then we we'll fall back to using this
	my $backupBookTitle;
	my $backupChapterTitle;

	foreach my $record (@$indRecord) {
		my ($recID,$type,$value) = @$record;
		$value =~ s/^\s{1,}//;
		#if ($type eq "title") {
		if ($type eq "title") {
			if ($value eq "") {
				$bookTitle = "No Book Title Supplied";
				$backupBookTitle = "No Book Title Supplied";
			} else {
				$bookTitle = substr $value, 0, 40;
				$backupBookTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "chapter") {
			if ($value eq "") {
				$chapterTitle = "No Chapter Title Supplied";
				$backupChapterTitle = "No Chapter Title Supplied";
			} else {
				$chapterTitle = substr $value, 0, 40;
				$backupChapterTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "container_title") {
			if ($value eq "") {
				$backupBookTitle = "No Book Title Supplied";
			} else {
				$backupBookTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "year") {
			$year = $value;
		}

		if ($type eq "volume") {
			if ($value ne "") {
				$vol = "VOL " . $value;
			}
		}

		if ($type eq "part_edition") {
			if ($value ne "") {
				$issue = "PT " . $value;
			}
		}

		if ($type eq "pages") {
			if ($value ne "") {
				$pages = "PP " . $value;
			}
		}

		#if ($type eq "article_title") {
		#	if ($value eq "") {
		#		$articleTitle = "No Article Title Supplied";
		#	} else {
		#		$articleTitle = substr $value, 0, 40;
		#	}
		#}

		if ($type eq "chapter_author") {
			if ($value ne "") {
				$author = substr $value, 0, 40;
				$author .= "\n";
			}
		}

		if ($type eq "isbn") {
			if ($value ne "") {
				$isbn = $value . "\n";
			}
		}
	}

	if ($chapterTitle eq "") {
		$chapterTitle = "No article title supplied";
	}

	if ($bookTitle eq "") {
		$bookTitle = $backupBookTitle;
	}
	
	$illAdminEmailBody .= $UHReqPrefix . $recID . "\n";
	$illAdminEmailBody .= $chapterTitle . "\n\n";

	$htmlBody .= $UHReqPrefix . $recID . "<br>\n";
	$htmlBody .= $chapterTitle . "<br><br>\n\n";

	my $dateIssueInfo = $year . " " . $vol . " " . $pages;

	if ($dateIssueInfo !~ m/[a-z,A-Z,0-9]/) {
		$dateIssueInfo = "No date,volume,pages number supplied";
	}

	$req .= $bookTitle . "\n" . $dateIssueInfo . "\n" . $chapterTitle . "\n" . $author . $isbn . $recordSep . $sedMessage . $email . "\n" . $recordSep;

	print "Chapter Request:\n" . $req . "\n" if $debug;

	return $req;
}

#################################################

sub processJournal($$$) {
	my $indRecord = $_[0];
	my $recID = $_[1];
	my $email = $_[2];
	return &processArticle($indRecord,$recID,$email);
}

#################################################

sub processBook($$) {

	my $indRecord = $_[0];
	my $recID = $_[1];

	my $req = $artEmailPrefix . $UHReqPrefix . $recID . " S LOAN\n";

	my ($bookTitle,$author,$publisher,$year,$yearDate,$isbn,$edition);

	foreach my $record (@$indRecord) {
		my ($recID,$type,$value) = @$record;
		$value =~ s/^\s{1,}//;

		if ($type eq "title") {
			if ($value eq "") {
				$bookTitle = "No Book Title Supplied";
			} else {
				$bookTitle = substr $value, 0, 40;
			}
		}

		if ($type eq "author") {
			if ($value ne "") {
				$author = substr $value, 0, 40;
				$author .= "\n";
			}
		}

		if ($type eq "publisher") {
			if ($value ne "") {
				$publisher = substr $value, 0, 40;
				$publisher .= "\n";
			}
		}

		if ($type eq "year") {
			$year = $value;
		}

		if ($type eq "part_edition") {
			$edition = $value;
		}


		if ($type eq "isbn") {
			if ($value ne "") {
				$isbn = $value . "\n";
				#$isbn =~ s/\s//g;
			}
		}

		#if ($type eq "$manual./metadata/titleLevel/thesisDissertation") {
			#$edition = $value;
		#}

	}

	# create year/edition line.
	if ($year ne "" ) {
			$yearDate = $year;
			if ($edition ne "") {
				$yearDate .= " ED/PT: " . $edition;
			}
	} else {
		if ($edition ne "") {
				$yearDate = " ED/PT: " . $edition;
		}
	}

	if ($yearDate ne "") {
			$yearDate .= "\n";
	}

	$illAdminEmailBody .= $UHReqPrefix . $recID . "\n";
	$illAdminEmailBody .= $bookTitle . "\n\n";

	$htmlBody .= $UHReqPrefix . $recID . "<br>\n";
	$htmlBody .= $bookTitle . "<br><br>\n\n";

	$req .= $bookTitle . "\n" . $author . $publisher . $yearDate . $isbn . $recordSep;

	print "Book Request:\n" . $req . "\n" if $debug;

	return $req;

}

#################################################

sub emailILLAdmin($) {

	print "emailILLAdmin sub\n" if $debug;

	my $emailText = $_[0];

	my $subject = "ILL Request Report";

	my $bytes = encode('utf8', $emailText);

	foreach my $receiver (@localEmails) {

		print "Sending $subject email to $receiver\n" if $debug;
		$htmlBody .= "emailILLAdmin sub: Sending $subject email to $receiver<br>\n";

		my %mail    = (
			charset => 'utf8',
			To      => "$receiver",
			From    => "$uhILLEmail",
			Subject => "$subject",
			Message => "$bytes"
		);

		sendmail(%mail);

	} # end of foreach

}

#################################################

sub emailProblemRequests($) {

	print "emailProblemRequests sub\n" if $debug;

	my $emailText = $_[0];

	my $subject = "Problem ILL Requests";

	my $bytes = encode('utf8', $emailText);

	foreach my $receiver (@localEmails) {

		print "Sending $subject email to $receiver\n" if $debug;
		$htmlBody .= "emailProblemRequests sub: Sending $subject email to $receiver<br>\n";

		my %mail    = (
			charset => 'utf8',
			To      => "$receiver",
			From    => "$uhILLEmail",
			Subject => "$subject",
			Message => "$bytes"
		);

		sendmail(%mail);

	} # end of foreach

}

##################################################

sub emailBL($) {

	my $emailText = $_[0];

	print "emailBL sub\n" if $debug;

	my $subject = "University of Hertfordshire ILL Requests";

	my $bytes = encode('utf8', $emailText);

	foreach my $receiver (@blILLEmail) {

		print "Sending $subject email to $receiver\n" if $debug;
		$htmlBody .= "emailBL sub: Sending $subject email to $receiver<br>\n";

		my %mail    = (
			charset => 'utf8',
			To      => "$receiver",
			From    => "$uhILLEmail",
			Subject => "$subject",
			Message => "$bytes"
		);

		sendmail(%mail);
	}
}

######################################################

sub updateStatus($) {

	my $ID = $_[0];
        my $request = Koha::Illrequests->find($ID);
        $request->status("REQ");
	#$request->status_alias("471");
	$request->status_alias("ARTEREQ");
        $request->store;
	$htmlBody .= $ID . " has been updated to REQ and status alias to ARTEMAIL<br>\n";
}
