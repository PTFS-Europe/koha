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

use CGI qw ( -utf8 );
use HTML::Entities;
use Try::Tiny;
use C4::Auth;
use C4::Context;
use C4::Koha;
use C4::Serials;    #uses getsubscriptionfrom biblionumber
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Circulation;
use C4::Reserves;
use C4::Serials;
use C4::XISBN qw(get_xisbns);
use C4::External::Amazon;
use C4::Search;        # enabled_staff_search_views
use C4::Tags qw(get_tags);
use C4::XSLT;
use Koha::DateUtils;
use C4::HTML5Media;
use C4::CourseReserves qw(GetItemCourseReservesInfo);
use C4::Acquisition qw(GetOrdersByBiblionumber);
use Koha::AuthorisedValues;
use Koha::Biblios;
use Koha::CoverImages;
use Koha::Illrequests;
use Koha::Database;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;
use Koha::Virtualshelves;
use Koha::Plugins;
use Koha::SearchEngine::Search;

my $schema = Koha::Database->new()->schema();

my $query = CGI->new();

my $analyze = $query->param('analyze');

my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user(
    {
    template_name   =>  'catalogue/detail.tt',
        query           => $query,
        type            => "intranet",
        flagsrequired   => { catalogue => 1 },
    }
);

# Determine if we should be offering any enhancement plugin buttons
if ( C4::Context->config('enable_plugins') ) {
    # Only pass plugins that can offer a toolbar button
    my @plugins = Koha::Plugins->new()->GetPlugins({
        method => 'intranet_catalog_biblio_enhancements_toolbar_button'
    });
    $template->param(
        plugins => \@plugins,
    );
}

my $biblionumber = $query->param('biblionumber');
$biblionumber = HTML::Entities::encode($biblionumber);
my $record       = GetMarcBiblio({ biblionumber => $biblionumber });
my $biblio = Koha::Biblios->find( $biblionumber );
$template->param( 'biblio', $biblio );

if ( not defined $record ) {
    # biblionumber invalid -> report and exit
    $template->param( unknownbiblionumber => 1,
                      biblionumber => $biblionumber );
    output_html_with_http_headers $query, $cookie, $template->output;
    exit;
}

eval { $biblio->metadata->record };
$template->param( decoding_error => $@ );

if($query->cookie("holdfor")){
    my $holdfor_patron = Koha::Patrons->find( $query->cookie("holdfor") );
    if ( $holdfor_patron ) {
        $template->param(
            # FIXME Should pass the patron object
            holdfor => $query->cookie("holdfor"),
            holdfor_surname => $holdfor_patron->surname,
            holdfor_firstname => $holdfor_patron->firstname,
            holdfor_cardnumber => $holdfor_patron->cardnumber,
        );
    }
}

if($query->cookie("searchToOrder")){
    my ( $basketno, $vendorid ) = split( /\//, $query->cookie("searchToOrder") );
    $template->param(
        searchtoorder_basketno => $basketno,
        searchtoorder_vendorid => $vendorid
    );
}

my $fw           = GetFrameworkCode($biblionumber);
my $showallitems = $query->param('showallitems');
my $marcflavour  = C4::Context->preference("marcflavour");

# XSLT processing of some stuff
my $xslfile = C4::Context->preference('XSLTDetailsDisplay') || "default";
my $lang   = $xslfile ? C4::Languages::getlanguage()  : undef;
my $sysxml = $xslfile ? C4::XSLT::get_xslt_sysprefs() : undef;

if ( $xslfile ) {

    my $searcher = Koha::SearchEngine::Search->new(
        { index => $Koha::SearchEngine::BIBLIOS_INDEX }
    );
    my $cleaned_title = $biblio->title;
    $cleaned_title =~ tr|/||;
    my $query =
      ( C4::Context->preference('UseControlNumber') and $record->field('001') )
      ? 'rcn:'. $record->field('001')->data . ' AND (bib-level:a OR bib-level:b)'
      : "Host-item:($cleaned_title)";
    my ( $err, $result, $count ) = $searcher->simple_search_compat( $query, 0, 0 );

    warn "Warning from simple_search_compat: $err"
        if $err;

    my $variables = {
        show_analytics_link => $count > 0 ? 1 : 0
    };

    $template->param(
        XSLTDetailsDisplay => '1',
        XSLTBloc           => XSLTParse4Display(
            $biblionumber, $record, "XSLTDetailsDisplay", 1,
            undef,         $sysxml, $xslfile,             $lang,
            $variables
        )
    );
}

$template->param( 'SpineLabelShowPrintOnBibDetails' => C4::Context->preference("SpineLabelShowPrintOnBibDetails") );

# Catch the exception as Koha::Biblio::Metadata->record can explode if the MARCXML is invalid
# Do not propagate it as we already deal with it previously in this script
my $coins = eval { $biblio->get_coins };
$template->param( ocoins => $coins );

# some useful variables for enhanced content;
# in each case, we're grabbing the first value we find in
# the record and normalizing it
my $upc = GetNormalizedUPC($record,$marcflavour);
my $ean = GetNormalizedEAN($record,$marcflavour);
my $oclc = GetNormalizedOCLCNumber($record,$marcflavour);
my $isbn = GetNormalizedISBN(undef,$record,$marcflavour);

$template->param(
    normalized_upc => $upc,
    normalized_ean => $ean,
    normalized_oclc => $oclc,
    normalized_isbn => $isbn,
);

my $marcnotesarray   = GetMarcNotes( $record, $marcflavour );

my $itemtypes = { map { $_->{itemtype} => $_ } @{ Koha::ItemTypes->search->unblessed } };

my $dbh = C4::Context->dbh;

my @all_items = GetItemsInfo( $biblionumber );
my @items;
my $patron = Koha::Patrons->find( $borrowernumber );
for my $itm (@all_items) {
    push @items, $itm unless ( $itm->{itemlost} && $patron->category->hidelostitems && !$showallitems);
}

# flag indicating existence of at least one item linked via a host record
my $hostrecords;
# adding items linked via host biblios
my @hostitems = GetHostItemsInfo($record);
if (@hostitems){
    $hostrecords =1;
    push (@items,@hostitems);
}

my $dat = &GetBiblioData($biblionumber);

#is biblio a collection
my $leader = $record->leader();
$dat->{collection} = ( substr($leader,7,1) eq 'c' ) ? 1 : 0;


#coping with subscriptions
my $subscriptionsnumber = CountSubscriptionFromBiblionumber($biblionumber);
my @subscriptions       = SearchSubscriptions({ biblionumber => $biblionumber, orderby => 'title' });
my @subs;

foreach my $subscription (@subscriptions) {
    my %cell;
    my $serials_to_display;
    $cell{subscriptionid}    = $subscription->{subscriptionid};
    $cell{subscriptionnotes} = $subscription->{internalnotes};
    $cell{missinglist}       = $subscription->{missinglist};
    $cell{librariannote}     = $subscription->{librariannote};
    $cell{branchcode}        = $subscription->{branchcode};
    $cell{hasalert}          = $subscription->{hasalert};
    $cell{callnumber}        = $subscription->{callnumber};
    $cell{location}          = $subscription->{location};
    $cell{closed}            = $subscription->{closed};
    #get the three latest serials.
    $serials_to_display = $subscription->{staffdisplaycount};
    $serials_to_display = C4::Context->preference('StaffSerialIssueDisplayCount') unless $serials_to_display;
    $cell{staffdisplaycount} = $serials_to_display;
    $cell{latestserials} =
      GetLatestSerials( $subscription->{subscriptionid}, $serials_to_display );
    push @subs, \%cell;
}


# Get acquisition details
if ( C4::Context->preference('AcquisitionDetails') ) {
    my $orders = Koha::Acquisition::Orders->search(
        { biblionumber => $biblionumber },
        {
            join => 'basketno',
            order_by => 'basketno.booksellerid'
        }
    );    # GetHistory sorted by aqbooksellerid, but does it make sense?

    $template->param(
        orders => $orders,
    );
}

if ( C4::Context->preference('suggestion') ) {
    my $suggestions = Koha::Suggestions->search(
        {
            biblionumber => $biblionumber,
            archived     => 0,
        },
        {
            order_by => { -desc => 'suggesteddate' }
        }
    );
    my $nb_archived_suggestions = Koha::Suggestions->search({ biblionumber => $biblionumber, archived => 1 })->count;
    $template->param( suggestions => $suggestions, nb_archived_suggestions => $nb_archived_suggestions );
}

if ( defined $dat->{'itemtype'} ) {
    $dat->{imageurl} = getitemtypeimagelocation( 'intranet', $itemtypes->{ $dat->{itemtype} }{imageurl} );
}

$dat->{'count'} = scalar @all_items + @hostitems;
$dat->{'showncount'} = scalar @items + @hostitems;
$dat->{'hiddencount'} = scalar @all_items + @hostitems - scalar @items;

my $shelflocations =
  { map { $_->{authorised_value} => $_->{lib} } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => $fw, kohafield => 'items.location' } ) };
my $collections =
  { map { $_->{authorised_value} => $_->{lib} } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => $fw, kohafield => 'items.ccode' } ) };
my $copynumbers =
  { map { $_->{authorised_value} => $_->{lib} } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => $fw, kohafield => 'items.copynumber' } ) };
my (@itemloop, @otheritemloop, %itemfields);

my $mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fw, kohafield => 'items.itemlost', authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
if ( $mss->count ) {
    $template->param( itemlostloop => GetAuthorisedValues( $mss->next->authorised_value ) );
}
$mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fw, kohafield => 'items.damaged', authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
if ( $mss->count ) {
    $template->param( itemdamagedloop => GetAuthorisedValues( $mss->next->authorised_value ) );
}
$mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fw, kohafield => 'items.withdrawn', authorised_value => { not => undef } });
if ( $mss->count ) {
    $template->param( itemwithdrawnloop => GetAuthorisedValues( $mss->next->authorised_value) );
}

$mss = Koha::MarcSubfieldStructures->search({ frameworkcode => $fw, kohafield => 'items.materials', authorised_value => [ -and => {'!=' => undef }, {'!=' => ''}] });
my %materials_map;
if ($mss->count) {
    my $materials_authvals = GetAuthorisedValues($mss->next->authorised_value);
    if ($materials_authvals) {
        foreach my $value (@$materials_authvals) {
            $materials_map{$value->{authorised_value}} = $value->{lib};
        }
    }
}

my $analytics_flag;
my $materials_flag; # set this if the items have anything in the materials field
my $currentbranch = C4::Context->userenv ? C4::Context->userenv->{branch} : undef;
if ($currentbranch and C4::Context->preference('SeparateHoldings')) {
    $template->param(SeparateHoldings => 1);
}
my $separatebranch = C4::Context->preference('SeparateHoldingsBranch') || 'homebranch';
my ( $itemloop_has_images, $otheritemloop_has_images );
foreach my $item (@items) {
    my $itembranchcode = $item->{$separatebranch};

    $item->{imageurl} = defined $item->{itype} ? getitemtypeimagelocation('intranet', $itemtypes->{ $item->{itype} }{imageurl})
                                               : '';

    $item->{datedue} = format_sqldatetime($item->{datedue});

    #get shelf location and collection code description if they are authorised value.
    # same thing for copy number
    my $shelfcode = $item->{'location'};
    $item->{'location'} = $shelflocations->{$shelfcode} if ( defined( $shelfcode ) && defined($shelflocations) && exists( $shelflocations->{$shelfcode} ) );
    my $ccode = $item->{'ccode'};
    $item->{'ccode'} = $collections->{$ccode} if ( defined( $ccode ) && defined($collections) && exists( $collections->{$ccode} ) );
    my $copynumber = $item->{'copynumber'};
    $item->{'copynumber'} = $copynumbers->{$copynumber} if ( defined($copynumber) && defined($copynumbers) && exists( $copynumbers->{$copynumber} ) );
    foreach (qw(ccode enumchron copynumber stocknumber itemnotes itemnotes_nonpublic uri publisheddate)) { # Warning when removing GetItemsInfo - publisheddate (at least) is not part of the items table
        $itemfields{$_} = 1 if ( $item->{$_} );
    }

    # checking for holds
    my $item_object = Koha::Items->find( $item->{itemnumber} );
    my $holds = $item_object->current_holds;
    if ( my $first_hold = $holds->next ) {
        $item->{first_hold} = $first_hold;
    }

    if ( my $checkout = $item_object->checkout ) {
        $item->{CheckedOutFor} = $checkout->patron;
    }

    # Check the transit status
    my ( $transfertwhen, $transfertfrom, $transfertto ) = GetTransfers($item->{itemnumber});
    if ( defined( $transfertwhen ) && ( $transfertwhen ne '' ) ) {
        $item->{transfertwhen} = $transfertwhen;
        $item->{transfertfrom} = $transfertfrom;
        $item->{transfertto}   = $transfertto;
        $item->{nocancel} = 1;
    }

    foreach my $f (qw( itemnotes )) {
        if ($item->{$f}) {
            $item->{$f} =~ s|\n|<br />|g;
            $itemfields{$f} = 1;
        }
    }

    #item has a host number if its biblio number does not match the current bib

    if ($item->{biblionumber} ne $biblionumber){
        $item->{hostbiblionumber} = $item->{biblionumber};
        $item->{hosttitle} = GetBiblioData($item->{biblionumber})->{title};
    }
	

    if ( $analyze ) {
        # count if item is used in analytical bibliorecords
        # The 'countanalytics' flag is only used in the templates if analyze is set
        my $countanalytics = C4::Context->preference('EasyAnalyticalRecords') ? GetAnalyticsCount($item->{itemnumber}) : 0;
        if ($countanalytics > 0){
            $analytics_flag=1;
            $item->{countanalytics} = $countanalytics;
        }
    }

    if (defined($item->{'materials'}) && $item->{'materials'} =~ /\S/){
        $materials_flag = 1;
        if (defined $materials_map{ $item->{materials} }) {
            $item->{materials} = $materials_map{ $item->{materials} };
        }
    }

    if ( C4::Context->preference('UseCourseReserves') ) {
        $item->{'course_reserves'} = GetItemCourseReservesInfo( itemnumber => $item->{'itemnumber'} );
    }

    if ( C4::Context->preference('IndependentBranches') ) {
        my $userenv = C4::Context->userenv();
        if ( not C4::Context->IsSuperLibrarian()
            and $userenv->{branch} ne $item->{homebranch} ) {
            $item->{cannot_be_edited} = 1;
        }
    }

    if ( C4::Context->preference("LocalCoverImages") == 1 ) {
        $item->{cover_images} = $item_object->cover_images;
    }

    if ($item_object->is_bundle) {
        $itemfields{bundles} = 1;
        $item->{is_bundle} = 1;
    }

    if ($item_object->in_bundle) {
        $item->{bundle_host} = $item_object->bundle_host;
    }

    if ($currentbranch and C4::Context->preference('SeparateHoldings')) {
        if ($itembranchcode and $itembranchcode eq $currentbranch) {
            push @itemloop, $item;
            $itemloop_has_images++ if $item_object->cover_images->count;
        } else {
            push @otheritemloop, $item;
            $otheritemloop_has_images++ if $item_object->cover_images->count;
        }
    } else {
        push @itemloop, $item;
        $itemloop_has_images++ if $item_object->cover_images->count;
    }
}

$template->param(
    itemloop_has_images      => $itemloop_has_images,
    otheritemloop_has_images => $otheritemloop_has_images,
);

# Display only one tab if one items list is empty
if (scalar(@itemloop) == 0 || scalar(@otheritemloop) == 0) {
    $template->param(SeparateHoldings => 0);
    if (scalar(@itemloop) == 0) {
        @itemloop = @otheritemloop;
    }
}

$template->param(
    MARCNOTES   => $marcnotesarray,
    itemdata_ccode      => $itemfields{ccode},
    itemdata_enumchron  => $itemfields{enumchron},
    itemdata_uri        => $itemfields{uri},
    itemdata_copynumber => $itemfields{copynumber},
    itemdata_stocknumber => $itemfields{stocknumber},
    itemdata_publisheddate => $itemfields{publisheddate},
    itemdata_bundles       => $itemfields{bundles},
    volinfo                => $itemfields{enumchron},
        itemdata_itemnotes  => $itemfields{itemnotes},
        itemdata_nonpublicnotes => $itemfields{itemnotes_nonpublic},
    z3950_search_params    => C4::Search::z3950_search_args($dat),
        hostrecords         => $hostrecords,
    analytics_flag    => $analytics_flag,
    C4::Search::enabled_staff_search_views,
        materials       => $materials_flag,
);

if (C4::Context->preference("AlternateHoldingsField") && scalar @items == 0) {
    my $fieldspec = C4::Context->preference("AlternateHoldingsField");
    my $subfields = substr $fieldspec, 3;
    my $holdingsep = C4::Context->preference("AlternateHoldingsSeparator") || ' ';
    my @alternateholdingsinfo = ();
    my @holdingsfields = $record->field(substr $fieldspec, 0, 3);

    for my $field (@holdingsfields) {
        my %holding = ( holding => '' );
        my $havesubfield = 0;
        for my $subfield ($field->subfields()) {
            if ((index $subfields, $$subfield[0]) >= 0) {
                $holding{'holding'} .= $holdingsep if (length $holding{'holding'} > 0);
                $holding{'holding'} .= $$subfield[1];
                $havesubfield++;
            }
        }
        if ($havesubfield) {
            push(@alternateholdingsinfo, \%holding);
        }
    }

    $template->param(
        ALTERNATEHOLDINGS   => \@alternateholdingsinfo,
        );
}

my @results = ( $dat, );
foreach ( keys %{$dat} ) {
    $template->param( "$_" => defined $dat->{$_} ? $dat->{$_} : '' );
}

# does not work: my %views_enabled = map { $_ => 1 } $template->query(loop => 'EnableViews');
# method query not found?!?!
$template->param( AmazonTld => get_amazon_tld() ) if ( C4::Context->preference("AmazonCoverImages"));
$template->param(
    itemloop        => \@itemloop,
    otheritemloop   => \@otheritemloop,
    biblionumber        => $biblionumber,
    ($analyze? 'analyze':'detailview') =>1,
    subscriptions       => \@subs,
    subscriptionsnumber => $subscriptionsnumber,
    subscriptiontitle   => $dat->{title},
    searchid            => scalar $query->param('searchid'),
);

# $debug and $template->param(debug_display => 1);

# Lists

if (C4::Context->preference("virtualshelves") ) {
    my $shelves = Koha::Virtualshelves->search(
        {
            biblionumber => $biblionumber,
            category => 2,
        },
        {
            join => 'virtualshelfcontents',
        }
    );
    $template->param( 'shelves' => $shelves );
}

# XISBN Stuff
if (C4::Context->preference("FRBRizeEditions")==1) {
    eval {
        $template->param(
            XISBNS => scalar get_xisbns($isbn, $biblionumber)
        );
    };
    if ($@) { warn "XISBN Failed $@"; }
}

if ( C4::Context->preference("LocalCoverImages") == 1 ) {
    my $images = $biblio->cover_images;
    $template->param( localimages => $biblio->cover_images );
}

# BDS Cover images
if( C4::Context->preference('BDSStaffEnable') == 1)
{
$template->param(DBMCode =>
C4::Context->preference('DBMCode') );
}


# HTML5 Media
if ( (C4::Context->preference("HTML5MediaEnabled") eq 'both') or (C4::Context->preference("HTML5MediaEnabled") eq 'staff') ) {
    $template->param( C4::HTML5Media->gethtml5media($record));
}

# Displaying tags
my $tag_quantity;
if (C4::Context->preference('TagsEnabled') and $tag_quantity = C4::Context->preference('TagsShowOnDetail')) {
    $template->param(
        TagsEnabled => 1,
        TagsShowOnDetail => $tag_quantity
    );
    $template->param(TagLoop => get_tags({biblionumber=>$biblionumber, approved=>1,
                                'sort'=>'-weight', limit=>$tag_quantity}));
}

#we only need to pass the number of holds to the template
my $holds = $biblio->holds;
$template->param( holdcount => $holds->count );

# Check if there are any ILL requests connected to the biblio
my $illrequests =
    C4::Context->preference('ILLModule')
  ? Koha::Illrequests->search( { biblio_id => $biblionumber } )
  : [];
$template->param( illrequests => $illrequests );

my $StaffDetailItemSelection = C4::Context->preference('StaffDetailItemSelection');
if ($StaffDetailItemSelection) {
    # Only enable item selection if user can execute at least one action
    if (
        $flags->{superlibrarian}
        || (
            ref $flags->{tools} eq 'HASH' && (
                $flags->{tools}->{items_batchmod}       # Modify selected items
                || $flags->{tools}->{items_batchdel}    # Delete selected items
            )
        )
        || ( ref $flags->{tools} eq '' && $flags->{tools} )
      )
    {
        $template->param(
            StaffDetailItemSelection => $StaffDetailItemSelection );
    }
}

$template->param(biblio => $biblio);

output_html_with_http_headers $query, $cookie, $template->output;
