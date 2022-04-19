#!/usr/bin/env perl

# Copyright 2012 PTFS Europe Ltd.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

# JCM testing >/tmp

use strict;
use warnings;
use Carp;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Biblio;    # GetMarcBiblio GetXmlBiblio
use C4::Koha;      # GetItemTypes
use Net::FTP;
use Mail::Sendmail;
use Encode;

unless ( chdir '/tmp' ) {
    croak 'Unable to cd to /tmp';
}

my $timestamp = localtime();
print $timestamp . "\n";

my $items_sort="dateaccessioned DESC";
my $items_limit="100";
my $filename = get_filename();

$filename =~ s/-full-/-updates-/;

write_file($filename);

#uncomment
transfer_file($filename);

$filename =~ s/-updates-/-deletes-/;
$filename =~ s/\.mrc$/\.txt/;

write_file($filename);

# uncomment
transfer_file($filename);

sub write_file {
    my $export_filename = shift;
    my $dbh             = C4::Context->dbh;
	
#    my $query =
#      'SELECT biblioitems.biblionumber FROM biblioitems WHERE biblionumber >0 ';
#
#    my $sth = $dbh->prepare($query);
#    $sth->execute();
#
#    open my $fh, '>:encoding(utf8)', $export_filename
#      or croak "Cannot open $export_filename : $!";
#
#    while ( my ($biblionumber) = $sth->fetchrow_array ) {
#        my $marc_record = GetMarcBiblio($biblionumber);
#        add_items_to_biblio($marc_record, $biblionumber);
#        if ($marc_record) {
#            print {$fh} $marc_record->as_usmarc();
#        }
#    }
#    if ( !close $fh ) {
#        croak "Writing to $export_filename failed on close";
    if ( $export_filename =~ m{-updates-} ) {
        my $query =
"SELECT biblio_metadata.biblionumber, ExtractValue(biblio_metadata.metadata,'//datafield[\@tag=\"245\"]/subfield[\@code>=\"a\"]') AS title FROM biblio_metadata WHERE (timestamp >= CURDATE() and timestamp < CURDATE() + INTERVAL 1 DAY) and biblio_metadata.timestamp not like '\%02:00:\%' AND ExtractValue(metadata, \'//datafield[\@tag=\"942\"]/subfield[\@code=\"n\"]\') <> '1' ORDER BY title";
#'SELECT biblioitems.biblionumber FROM biblioitems WHERE (timestamp >= date(now() - interval 1 day)) and (timestamp < date(now())) ';

        my $sth = $dbh->prepare($query);
        $sth->execute();

        open my $fh, '>:encoding(utf8)', $export_filename
          or croak "Cannot open $export_filename : $!";
		  
		my $emailText = "";
		my $count = 0;

        while ( my ($biblionumber, $title) = $sth->fetchrow_array ) {
			$count++;
			$emailText .= $title . "\n";
			$emailText .= 'https://library.herts.ac.uk/cgi-bin/koha/opac-detail.pl?biblionumber=' . $biblionumber . "\n\n";

		my $bibHash = { biblionumber => $biblionumber };
		my $marc_record = GetMarcBiblio($bibHash);
	
        	add_items_to_biblio($marc_record, $biblionumber);

            #	my $marc_record = GetMarcBiblio($biblionumber);
            if ($marc_record) {
                print {$fh} $marc_record->as_usmarc();
            }
        }
        if ( !close $fh ) {
            croak "Writing to $export_filename failed on close";
        }
		
		$emailText = $count . " updated/new records copied over to Summon\n\n" . $emailText;
		#print $emailText . "\n";
		&sendEmail($emailText);
		
    }
    else {
        my $query =
'select biblionumber from deletedbiblioitems WHERE timestamp >= date(now() - interval 1 day) and timestamp < date(now()) ';
        my $sth = $dbh->prepare($query);
        $sth->execute();
        open my $fh, '>:encoding(utf8)', $export_filename
          or croak "Cannot open $export_filename : $!";
        while ( my ($biblionumber) = $sth->fetchrow_array ) {
            print {$fh} "$biblionumber\n";
        }
	$query =
'select biblionumber from biblio_metadata where ExtractValue(metadata, \'//datafield[@tag="942"]/subfield[@code="n"]\') = "1"';
	#$query =
#'select biblionumber from biblio_metadata where ExtractValue(metadata, \'//datafield[@tag="942"]/subfield[@code="n"]\') <> "1"';
        $sth = $dbh->prepare($query);
        $sth->execute();
        while ( my ($biblionumber) = $sth->fetchrow_array ) {
            print {$fh} "$biblionumber\n";
        }
        if ( !close $fh ) {
            croak "Writing to $export_filename failed on close";
        }
    }
    return;
}

sub add_items_to_biblio {
    my $record       = shift;
    my $biblionumber = shift;
my $dbh = C4::Context->dbh;
    return unless $record && $biblionumber;

    my $items_query = q{
        SELECT itemnumber
        FROM items
        WHERE biblionumber = ?
    };
    if ($items_sort) {
        $items_query .= q{ ORDER BY } . $items_sort;
    }
    $items_query .= q{ LIMIT } . $items_limit if ($items_limit);
    my $items_sth = $dbh->prepare($items_query);
    $items_sth->execute($biblionumber);

    my @itemnumbers;
    while ( my $itemnumber = $items_sth->fetchrow_array ) {
        push @itemnumbers, $itemnumber;
    }

    #C4::Biblio::EmbedItemsInMarcBiblio( $record, $biblionumber, \@itemnumbers )
    # if (@itemnumbers);

    # changed by sg13abk on the 25th Feb 2022
    # to enable item info in the updates
    C4::Biblio::EmbedItemsInMarcBiblio( {
        "marc_record" => $record,
        "biblionumber" => $biblionumber,
        "item_numbers" => \@itemnumbers } )
     if (@itemnumbers);
}

sub get_filename {

    #    my @abbr  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    #    my @tm    = localtime();
    #    my $month = $tm[4];
    #    my $year  = $tm[5] - 100;
    #    my $name  = 'staffs-catalog-' . $abbr[$month] . $year;
    my $name = `date +%F-%H-%M-%S`;
    chomp $name;
    $name = 'hert-catalog-full-' . $name . '.mrc';

    #    $name .= '.marc';

    # will need to add a directory & unique date id to file
    return $name;
}

sub transfer_file {
    my $marc_file = shift;
    my $remote    = 'ftp.summon.serialssolutions.com';
    my $username  = q(herts-catalog);
    my $password  = q(96PeL5hEmc);

    my $ftp = Net::FTP->new( $remote, Debug => 1, Passive => 1 )
      or croak "Cannot connect to smartsm: $@";

    $ftp->login( $username, $password )
      or croak 'Cannot login to SmartSM ', $ftp->message;
#    $ftp->cwd("/full")
#      or croak "Cannot change working directory ", $ftp->message;
    if ( $marc_file =~ m{-updates-} ) {
        $ftp->cwd("/updates")
          or croak "Cannot change working directory ", $ftp->message;
    }
    else {
        $ftp->cwd("/deletes")
          or croak "Cannot change working directory ", $ftp->message;
    }
    $ftp->binary();
    $ftp->put($marc_file);

    $ftp->quit;

    return;
}

#######################################

sub sendEmail($) {

	my $message = $_[0];
	my $m = encode('utf8',$message);
	my $email = 's.graham4@herts.ac.uk books@herts.ac.uk';
	# my $email = 's.graham4@herts.ac.uk';
	my $subject = "Koha records sent to Summon";
	
	my %mail    = (
        To      => "$email",
        From    => 'libraryaccount@herts.ac.uk',
        Subject => "$subject",
        Message => "$m"
    );
	# commeneted out because test server does not send emails
	sendmail(%mail);

}
