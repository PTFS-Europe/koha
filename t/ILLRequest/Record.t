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

use Test::More; # tests => 8;
use Test::Exception;
use Test::Warn;
use XML::LibXML;
use BLDSS;
use Koha::ILLRequest::Abstract;
use Koha::ILLRequest::XML::BLDSS;
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

# Helper function unit test
my $tmp = XML::LibXML->new()->load_xml( { string => '<availability><loanAvailabilityDate>2015-01-08</loanAvailabilityDate><copyAvailabilityDate>2015-01-08</copyAvailabilityDate><copyrightFee currency="GBP">12.0</copyrightFee><availableImmediately>false</availableImmediately><matchedToSpecificItem>true</matchedToSpecificItem><isOnOrder>false</isOnOrder><availableFormats><availableFormat availabilityDate="2015-01-08"><deliveryFormat key="1">Encrypted Download</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat><availableFormat availabilityDate="2015-01-08"><deliveryFormat key="4">Paper</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat></availableFormats></availability>' } );
my $datum = ${$tmp->findnodes('availability')}[0];
is(${$record->_parseResponse($datum, "avail")}{"./copyrightFee/\@currency"}{value},
   "GBP", "Parse Availability Response");
#diag(dump($record->_parseResponse($datum, "avail")));

my $response = Koha::ILLRequest::XML::BLDSS->new->load_xml( { string => '<?xml version="1.0" encoding="UTF-8"?><apiResponse><timestamp>2015-01-12 14:12:16.60 GMT</timestamp><status>5</status><message>Weasels ate our wires.</message><result/></apiResponse>' } );
dies_ok( sub { $record->checkPrices($response) }, "Non-0 status detected");

# API function unit test.
$response = Koha::ILLRequest::XML::BLDSS->new->load_xml( { string => '<?xml version="1.0" encoding="UTF-8"?><apiResponse><timestamp>2015-01-12 13:33:16.107 GMT</timestamp><status>0</status><message/><result><availability><loanAvailabilityDate>2015-01-12</loanAvailabilityDate><copyAvailabilityDate>2015-01-12</copyAvailabilityDate><copyrightFee currency="GBP">12.0</copyrightFee><availableImmediately>false</availableImmediately><matchedToSpecificItem>true</matchedToSpecificItem><isOnOrder>false</isOnOrder><availableFormats><availableFormat availabilityDate="2015-01-12"><deliveryFormat key="1">Encrypted Download</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat><availableFormat availabilityDate="2015-01-12"><deliveryFormat key="4">Paper</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat></availableFormats></availability></result></apiResponse>' } );
isa_ok($record->checkAvailability($response),
       "Koha::ILLRequest::XML::BLDSS::Availability");

# checkPrices
$response = Koha::ILLRequest::XML::BLDSS->new->load_xml( { string => '<?xml version="1.0" encoding="UTF-8"?><apiResponse><timestamp>2015-01-12 14:12:16.60 GMT</timestamp><status>0</status><message/><result><currency>GBP</currency><region>UK</region><copyrightVat>.2</copyrightVat><loanRenewalCost>4.55</loanRenewalCost><services><service id="4"><format vat=".2"><price>5.21</price></format></service><service id="7"><format vat=".2"><price>9.55</price></format></service><service id="8"><format vat=".2"><price>4.25</price></format></service><service id="1"><format id="1" vat=".2"><price speed="1" quality="1">5</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">25</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">16</price><price speed="3" quality="2">45.75</price><price speed="4" quality="1">8.95</price><price speed="4" quality="2">29.2</price></format><format id="2" vat=".2"><price speed="1" quality="1">6</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">31</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">17</price><price speed="3" quality="2">46.9</price><price speed="4" quality="1">10.25</price><price speed="4" quality="2">29.2</price></format><format id="3" vat=".2"><price speed="1" quality="1">5.5</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">29</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">16.5</price><price speed="3" quality="2">46.9</price><price speed="4" quality="1">9.5</price><price speed="4" quality="2">29.2</price></format><format id="4" vat="0"><price speed="2" quality="1">27</price><price speed="2" quality="2">58.05</price><price speed="3" quality="1">19.5</price><price speed="3" quality="2">48.5</price><price speed="4" quality="1">10.45</price><price speed="4" quality="2">30.05</price></format><format id="5" vat=".2"><price speed="3" quality="1">19</price><price speed="3" quality="2">48.5</price><price speed="4" quality="1">11.8</price><price speed="4" quality="2">30.8</price></format><format id="6" vat="0"><price speed="3">24.1</price><price speed="4">14.1</price></format></service></services></result></apiResponse>' } );
isa_ok($record->checkPrices($response),
       "Koha::ILLRequest::XML::BLDSS::Result");

my $result = $record->checkPrices($response);

is_deeply( [ $result->currency, $result->loanRenewalCost ], [ "GBP", "4.55" ],
           "checkPrice Elements");
isa_ok(${$result->services}[0], "Koha::ILLRequest::XML::BLDSS::Service");

done_testing();
