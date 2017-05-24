#!/usr/bin/perl
#
use strict;
use warnings;

use lib '/home/koha/kohaclone';
use DBI;
use C4::Context;

$ENV{KOHA_CONF} = '/home/koha/koha-dev/etc/koha-conf.xml';

my $dbh = C4::Context->dbh;

#drop table stat_from_marcxml;
my $create_stmt = <<'ENDSQL';
create table stat_from_marcxml
select
biblionumber,
substr(ExtractValue(metadata, '//leader'),8,1) as itemtype,
ExtractValue(metadata,'//datafield[@tag="859"]/subfield[@code="c"]') as cataloguerm,
ExtractValue(metadata,'//datafield[@tag="923"]/subfield[@code="a"]') as cataloguers,
substr(ExtractValue(metadata,'//controlfield[@tag="008"]'),1,6) as insertdate,
substr(ExtractValue(metadata,'//controlfield[@tag="005"]'),1,8) as modifydate,
ExtractValue(metadata,'//controlfield[@tag="001"]') as accessionno,
ExtractValue(metadata,'//datafield[@tag="020"]/subfield[@code="a"]') as isbn,
ExtractValue(metadata,'//datafield[@tag="022"]/subfield[@code="a"]') as issn,
ExtractValue(metadata,'//datafield[@tag="084"]/subfield[@code="a"]') as callnumber,
ExtractValue(metadata,'//datafield[@tag="245"]/subfield[@code="a"]') as title
from biblio_metadata
ENDSQL

$dbh->do('drop table stat_from_marcxml');

my $sth = $dbh->prepare($create_stmt);

$sth->execute();
