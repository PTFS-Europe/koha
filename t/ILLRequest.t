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

use Test::More;
use Test::Warn;
use Data::Dump qw(dump);
use Koha::ILLRequest::XML::BLDSS;

BEGIN {
    use_ok('Koha::ILLRequest');
}

my $illRequest = Koha::ILLRequest->new;
isa_ok($illRequest, 'Koha::ILLRequest');

# mock data
my $doc = XML::LibXML->new()->load_xml( { string => "<record><uin>BLL01015482483</uin><type>book</type><isAvailableImmediateley>false</isAvailableImmediateley><metadata><titleLevel><title>James Joyce / edited by Sean Latham.</title><identifier>ISBN 9780716529064 (cased)</identifier><isbn>9780716529064|0716529068|9780716529071|0716529076</isbn><shelfmark>Document Supply m10/.19782</shelfmark><publisher>Dublin : Irish Academic Press, 2010.</publisher></titleLevel><itemLevel><year>2010</year></itemLevel><itemOfInterestLevel/></metadata></record>" } );
my $node = $doc->find("./record")->pop;
$illRequest->_seed_for_test($node);

# save

# checkAvailability

# checkSimpleAvailability
my $response = Koha::ILLRequest::XML::BLDSS ->new->load_xml( { string => '<?xml version="1.0" encoding="UTF-8"?><apiResponse><timestamp>2015-01-12 13:33:16.107 GMT</timestamp><status>0</status><message/><result><availability><loanAvailabilityDate>2015-01-12</loanAvailabilityDate><copyAvailabilityDate>2015-01-12</copyAvailabilityDate><copyrightFee currency="GBP">12.0</copyrightFee><availableImmediately>false</availableImmediately><matchedToSpecificItem>true</matchedToSpecificItem><isOnOrder>false</isOnOrder><availableFormats><availableFormat availabilityDate="2015-01-12"><deliveryFormat key="1">Encrypted Download</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat><availableFormat availabilityDate="2015-01-12"><deliveryFormat key="4">Paper</deliveryFormat><deliveryModifiers/><availableSpeeds><speed key="2">2 Hours</speed><speed key="3">24 Hours</speed><speed key="4">4 Days</speed></availableSpeeds><availableQuality><quality key="1">Standard</quality><quality key="2">High</quality></availableQuality></availableFormat></availableFormats></availability></result></apiResponse>' } );

is_deeply($illRequest->checkSimpleAvailability($response),
          {
           availableImmediately => ["Available immediately?", "false"],
           copyrightFee => ["Copyright fee", "12.0"],
           formats => [
                       "Formats",
                       [
                        {
                         format => ["Format", "Encrypted Download"],
                         key => ["Key", 1],
                         qualities => [
                                       "Qualities",
                                       [
                                        { key => ["Key", 1], quality => ["Quality", "Standard"] },
                                        { key => ["Key", 2], quality => ["Quality", "High"] },
                                       ],
                                      ],
                         speeds => [
                                    "Speeds",
                                    [
                                     { key => ["Key", 2], speed => ["Speed", "2 Hours"] },
                                     { key => ["Key", 3], speed => ["Speed", "24 Hours"] },
                                     { key => ["Key", 4], speed => ["Speed", "4 Days"] },
                                    ],
                                   ],
                        },
                        {
                         format => ["Format", "Paper"],
                         key => ["Key", 4],
                         qualities => [
                                       "Qualities",
                                       [
                                        { key => ["Key", 1], quality => ["Quality", "Standard"] },
                                        { key => ["Key", 2], quality => ["Quality", "High"] },
                                       ],
                                      ],
                         speeds => [
                                    "Speeds",
                                    [
                                     { key => ["Key", 2], speed => ["Speed", "2 Hours"] },
                                     { key => ["Key", 3], speed => ["Speed", "24 Hours"] },
                                     { key => ["Key", 4], speed => ["Speed", "4 Days"] },
                                    ],
                                   ],
                        },
                       ],
                      ],
          },
          "Simple Availability Output");

# editStatus

# status

# getPrices
# Covered by Abstract getPrices test.

# summary

# fullRequest

# getForEditing

# update

# seed_from_api's

# seed_from_store

done_testing();
