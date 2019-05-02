#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# parts copyright 2010 BibLibre
#
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


=head1 NAME

opac-ISBDdetail.pl - script to show a biblio in ISBD format

=head1 DESCRIPTION

This script needs a biblionumber as parameter 

It shows the biblio

The template is in <templates_dir>/catalogue/ISBDdetail.tt.
this template must be divided into 11 "tabs".

The first 10 tabs present the biblio, the 11th one presents
the items attached to the biblio

=head1 FUNCTIONS

=cut

use Modern::Perl;

use C4::Auth;
use C4::Context;
use C4::Output;
use CGI qw ( -utf8 );
use MARC::Record;
use C4::Biblio;
use C4::Items;
use C4::Reserves;
use C4::Acquisition;
use C4::Serials;    # uses getsubscriptionfrom biblionumber
use C4::Koha;
use Koha::IssuingRules;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;
use Koha::RecordProcessor;
use Koha::Biblios;

my $query = CGI->new();
my $biblionumber = $query->param('biblionumber');
if ( !$biblionumber ) {
    print $query->redirect('/cgi-bin/koha/errors/404.pl');
    exit;
}
$biblionumber = int($biblionumber);

#open template
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-ISBDdetail.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
        debug           => 1,
    }
);

my $patron = Koha::Patrons->find( $loggedinuser );
my $borcat = q{};
if ( $patron && C4::Context->preference('OpacHiddenItemsExceptions') ) {
    $borcat = $patron->categorycode;
}

my $record = GetMarcBiblio({
    biblionumber => $biblionumber,
    embed_items  => 1,
    opac         => 1,
    borcat       => $borcat });
if ( ! $record ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my @all_items = GetItemsInfo($biblionumber);
my $biblio = Koha::Biblios->find( $biblionumber );
my $framework = $biblio ? $biblio->frameworkcode : q{};
my ($tag_itemnumber, $subtag_itemnumber) = &GetMarcFromKohaField('items.itemnumber',$framework);
my @nonhiddenitems = $record->field($tag_itemnumber);
if (scalar @all_items >= 1 && scalar @nonhiddenitems == 0) {
    print $query->redirect('/cgi-bin/koha/errors/404.pl'); # escape early
    exit;
}

my $record_processor = Koha::RecordProcessor->new({
    filters => 'ViewPolicy',
    options => {
        interface => 'opac',
        frameworkcode => $framework
    }
});
$record_processor->process($record);

# get biblionumbers stored in the cart
if(my $cart_list = $query->cookie("bib_list")){
    my @cart_list = split(/\//, $cart_list);
    if ( grep {$_ eq $biblionumber} @cart_list) {
        $template->param( incart => 1 );
    }
}

my $marcflavour      = C4::Context->preference("marcflavour");

# some useful variables for enhanced content;
# in each case, we're grabbing the first value we find in
# the record and normalizing it
my $upc = GetNormalizedUPC($record,$marcflavour);
my $ean = GetNormalizedEAN($record,$marcflavour);
my $oclc = GetNormalizedOCLCNumber($record,$marcflavour);
my $isbn = GetNormalizedISBN(undef,$record,$marcflavour);
my $content_identifier_exists;
if ( $isbn or $ean or $oclc or $upc ) {
    $content_identifier_exists = 1;
}
$template->param(
    normalized_upc => $upc,
    normalized_ean => $ean,
    normalized_oclc => $oclc,
    normalized_isbn => $isbn,
    content_identifier_exists => $content_identifier_exists,
);

#coping with subscriptions
my $subscriptionsnumber = CountSubscriptionFromBiblionumber($biblionumber);
my $dat                 = TransformMarcToKoha( $record );

my @subscriptions       = SearchSubscriptions({ biblionumber => $biblionumber, orderby => 'title' });
my @subs;
foreach my $subscription (@subscriptions) {
    my %cell;
	my $serials_to_display;
    $cell{subscriptionid}    = $subscription->{subscriptionid};
    $cell{subscriptionnotes} = $subscription->{notes};
    $cell{branchcode}        = $subscription->{branchcode};

    #get the three latest serials.
	$serials_to_display = $subscription->{opacdisplaycount};
	$serials_to_display = C4::Context->preference('OPACSerialIssueDisplayCount') unless $serials_to_display;
	$cell{opacdisplaycount} = $serials_to_display;
    $cell{latestserials} =
      GetLatestSerials( $subscription->{subscriptionid}, $serials_to_display );
    push @subs, \%cell;
}

$template->param(
    subscriptions       => \@subs,
    subscriptionsnumber => $subscriptionsnumber,
);

my $norequests = 1;
my $allow_onshelf_holds;
my $res = GetISBDView({
    'record'    => $record,
    'template'  => 'opac',
    'framework' => $framework
});

my $itemtypes = { map { $_->{itemtype} => $_ } @{ Koha::ItemTypes->search_with_localization->unblessed } };
for my $itm (@all_items) {
    my $item = Koha::Items->find( $itm->{itemnumber} );
    $norequests = 0
      if $norequests
        && !$itm->{'withdrawn'}
        && !$itm->{'itemlost'}
        && ($itm->{'itemnotforloan'}<0 || not $itm->{'itemnotforloan'})
        && !$itemtypes->{$itm->{'itype'}}->{notforloan}
        && $itm->{'itemnumber'};

    $allow_onshelf_holds = Koha::IssuingRules->get_onshelfholds_policy( { item => $item, patron => $patron } )
      unless $allow_onshelf_holds;
}

if( $allow_onshelf_holds || CountItemsIssued($biblionumber) || $biblio->has_items_waiting_or_intransit ) {
    $template->param( ReservableItems => 1 );
}

$template->param(
    RequestOnOpac       => C4::Context->preference("RequestOnOpac"),
    norequests   => $norequests,
    ISBD         => $res,
    biblio       => $biblio,
);

#Search for title in links
my $marccontrolnumber   = GetMarcControlnumber ($record, $marcflavour);
my $marcissns = GetMarcISSN ( $record, $marcflavour );
my $issn = $marcissns->[0] || '';

if (my $search_for_title = C4::Context->preference('OPACSearchForTitleIn')){
    $dat->{title} =~ s/\/+$//; # remove trailing slash
    $dat->{title} =~ s/\s+$//; # remove trailing space
    $search_for_title = parametrized_url(
        $search_for_title,
        {
            TITLE         => $dat->{title},
            AUTHOR        => $dat->{author},
            ISBN          => $isbn,
            ISSN          => $issn,
            CONTROLNUMBER => $marccontrolnumber,
            BIBLIONUMBER  => $biblionumber,
        }
    );
    $template->param('OPACSearchForTitleIn' => $search_for_title);
}

if( C4::Context->preference('ArticleRequests') ) {
    my $itemtype = Koha::ItemTypes->find($biblio->itemtype);
    my $artreqpossible = $patron
        ? $biblio->can_article_request( $patron )
        : $itemtype
        ? $itemtype->may_article_request
        : q{};
    $template->param( artreqpossible => $artreqpossible );
}

output_html_with_http_headers $query, $cookie, $template->output;
