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

use Test::More; #tests => 9;
use Test::Warn;
use XML::LibXML;
use BLDSS;
use Koha::ILLRequest::Abstract;
use Koha::ILLRequest::XML::BLDSS;
use Data::Dump qw(dump);

# checkPrices
# Helper function unit test.
my $priceResult = Koha::ILLRequest::XML::BLDSS->new()->load_xml( { string => '<?xml version="1.0" encoding="UTF-8"?><apiResponse><timestamp>2015-01-12 14:12:16.60 GMT</timestamp><status>0</status><message/><result><currency>GBP</currency><region>UK</region><copyrightVat>.2</copyrightVat><loanRenewalCost>4.55</loanRenewalCost><services><service id="4"><format vat=".2"><price>5.21</price></format></service><service id="7"><format vat=".2"><price>9.55</price></format></service><service id="8"><format vat=".2"><price>4.25</price></format></service><service id="1"><format id="1" vat=".2"><price speed="1" quality="1">5</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">25</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">16</price><price speed="3" quality="2">45.75</price><price speed="4" quality="1">8.95</price><price speed="4" quality="2">29.2</price></format><format id="2" vat=".2"><price speed="1" quality="1">6</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">31</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">17</price><price speed="3" quality="2">46.9</price><price speed="4" quality="1">10.25</price><price speed="4" quality="2">29.2</price></format><format id="3" vat=".2"><price speed="1" quality="1">5.5</price><price speed="1" quality="2">5.25</price><price speed="2" quality="1">29</price><price speed="2" quality="2">56.5</price><price speed="3" quality="1">16.5</price><price speed="3" quality="2">46.9</price><price speed="4" quality="1">9.5</price><price speed="4" quality="2">29.2</price></format><format id="4" vat="0"><price speed="2" quality="1">27</price><price speed="2" quality="2">58.05</price><price speed="3" quality="1">19.5</price><price speed="3" quality="2">48.5</price><price speed="4" quality="1">10.45</price><price speed="4" quality="2">30.05</price></format><format id="5" vat=".2"><price speed="3" quality="1">19</price><price speed="3" quality="2">48.5</price><price speed="4" quality="1">11.8</price><price speed="4" quality="2">30.8</price></format><format id="6" vat="0"><price speed="3">24.1</price><price speed="4">14.1</price></format></service></services></result></apiResponse>' } )
  ->result;

isa_ok($priceResult, 'Koha::ILLRequest::XML::BLDSS::Result');
isa_ok($priceResult->services, 'ARRAY');
isa_ok($priceResult->get_service("4"),
       'Koha::ILLRequest::XML::BLDSS::Service');
isa_ok(${${$priceResult->services}[0]->formats}[0],
       'Koha::ILLRequest::XML::BLDSS::Format');

is($priceResult->currency, "GBP", "Currency");
is($priceResult->currency("EUR"), "EUR", "Currency");

done_testing();

