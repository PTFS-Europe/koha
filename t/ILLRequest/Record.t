#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More; # tests => 2;
use Test::Warn;
use XML::LibXML;
use BLDSS;
use Koha::ILLRequest::Abstract;

# mock data
my $doc = XML::LibXML->new()->load_xml( { string => "<record><uin>BLL01015482483</uin><type>book</type><isAvailableImmediateley>false</isAvailableImmediateley><metadata><titleLevel><title>James Joyce / edited by Sean Latham.</title><identifier>ISBN 9780716529064 (cased)</identifier><isbn>9780716529064|0716529068|9780716529071|0716529076</isbn><shelfmark>Document Supply m10/.19782</shelfmark><publisher>Dublin : Irish Academic Press, 2010.</publisher></titleLevel><itemLevel><year>2010</year></itemLevel><itemOfInterestLevel/></metadata></record>" } );
my $node = $doc->find("./record")->pop;

# tests
# module
BEGIN {
    use_ok('Koha::ILLRequest::Record');
}

# new
my $record = Koha::ILLRequest::Record->new(Koha::ILLRequest::Config->new());
isa_ok($record, 'Koha::ILLRequest::Record');

# create_from_xml
$record->create_from_xml($node);
is(${$record}{data}{uin}{value}, "BLL01015482483", "Created from XML");

# getSummary
is_deeply($record->getSummary, {
                                metadata_itemLevel_edition => ["Edition", ""],
                                metadata_itemLevel_year => ["Year", 2010],
                                metadata_titleLevel_author => ["Author", ""],
                                metadata_titleLevel_isbn => ["ISBN", "9780716529064|0716529068|9780716529071|0716529076"],
                                metadata_titleLevel_issn => ["ISSN", ""],
                                metadata_titleLevel_publisher => ["Publisher", "Dublin : Irish Academic Press, 2010."],
                                metadata_titleLevel_title => ["Title", "James Joyce / edited by Sean Latham."],
                                type => ["Material Type", "book"],
                                uin => ["British Library Identifier", "BLL01015482483"],
                               }, "Got summary");

# getProperty
is($record->getProperty('title'), "BLL01015482483", "Gotten property");

# checkAvailability
is(${pop($record->checkAvailability)}{matchedToSpecificItem}[1], "true", "Available?");
diag(dump($record->checkAvailability));

done_testing();
