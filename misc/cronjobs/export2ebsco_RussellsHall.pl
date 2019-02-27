#!/usr/bin/env perl

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

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../..";
use Carp;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Biblio;    # GetMarcBiblio GetXmlBiblio
use C4::Koha;      # GetItemTypes
use Net::FTP;

unless ( chdir '/tmp' ) {
    croak 'Unable to cd to /tmp';
}

my $filename = get_filename();

write_file($filename);

transfer_file($filename);

sub write_file {
    my $export_filename = shift;
    my $dbh             = C4::Context->dbh;

    my $query =
      'SELECT distinct biblioitems.biblionumber FROM biblioitems WHERE biblionumber >0 ';

    my $sth = $dbh->prepare($query);
    $sth->execute();

    open my $fh, '>:encoding(utf8)', $export_filename
      or croak "Cannot open $export_filename : $!";

    while ( my ($biblionumber) = $sth->fetchrow_array ) {
         my $marc_record = GetMarcBiblio({ biblionumber => $biblionumber,embed_items => 1});
#        my $marc_record = GetMarcBiblio($biblionumber, 1);
        if ($marc_record) {
            print {$fh} $marc_record->as_usmarc();
        }
    }
    if ( !close $fh ) {
        croak "Writing to $export_filename failed on close";
    }
    return;
}

sub get_filename {
    my @abbr  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my @tm    = localtime();
    my $month = $tm[4];
    my $year  = $tm[5] - 100;
    my $name  = 'RussellsHall-export' . $abbr[$month] . $year;

    $name .= '.mrc';

    # will need to add a directory & unique date id to file
    return $name;
}

sub transfer_file {
    my $marc_file = shift;
    my $remote    = 'ftp.epnet.com';
    my $username  = q(cat06461a);
    my $password = q(^Bc\]53;BM);

    my $ftp = Net::FTP->new( $remote, Debug => 0 )
      or croak "Cannot connect to epnet: $@";

  $ftp->login( $username, $password )
      or croak 'Cannot login to Epnet ', $ftp->message;
    $ftp->cwd("full")
          or die "Cannot change working directory ", $ftp->message;
    $ftp->put($marc_file);

   $ftp->quit;

    return;
}
