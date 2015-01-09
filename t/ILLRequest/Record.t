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

use Test::More tests => 7;
use Test::Warn;
use XML::LibXML;
use BLDSS;
use Koha::ILLRequest::Abstract;
use Data::Dump qw(dump);

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
is(${$record}{data}{"./uin"}{value}, "BLL01015482483", "Created from XML");
#diag(dump($record));

# getSummary
is_deeply($record->getSummary, {
                                "./metadata/itemLevel/edition" => ["Edition", ""],
                                "./metadata/itemLevel/year" => ["Year", 2010],
                                "./metadata/titleLevel/author" => ["Author", ""],
                                "./metadata/titleLevel/isbn" => ["ISBN", "9780716529064|0716529068|9780716529071|0716529076"],
                                "./metadata/titleLevel/issn" => ["ISSN", ""],
                                "./metadata/titleLevel/publisher" => ["Publisher", "Dublin : Irish Academic Press, 2010."],
                                "./metadata/titleLevel/title" => ["Title", "James Joyce / edited by Sean Latham."],
                                "./type" => ["Material Type", "book"],
                                "./uin" => ["British Library Identifier", "BLL01015482483"],
                               }, "Got summary");

# getProperty
is($record->getProperty('id'), "BLL01015482483", "Gotten property");
is($record->getProperty('title'), 'James Joyce / edited by Sean Latham.',
   "Gotten property");

# checkAvailability
my $tmp = XML::LibXML->new()->load_xml( { string => '<availability><loanAvailabilityDate>2015-01-08</loanAvailabilityDate><copyAvailabilityDate>2015-01-08</copyAvailabilityDate><copyrightFee currency="GBP">12.0</copyrightFee><availableImmediately>false</availableImmediately><matchedToSpecificItem>true</matchedToSpecificItem><isOnOrder>false</isOnOrder><availableFormats><availableFormat availabilityDate="2015-01-08"><deliveryFormat key="1">Encrypted Download</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat><availableFormat availabilityDate="2015-01-08"><deliveryFormat key="4">Paper</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat></availableFormats></availability>' } );
foreach my $datum ($tmp->findnodes('availability')) {
    is(${$record->_parseResponse($datum, "avail")}{"./copyrightFee/\@currency"}[1],
       "GBP", "Parse Response");
}
#is(${pop($record->checkAvailability)}{matchedToSpecificItem}[1], "true", "Available?");
