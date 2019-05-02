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
use List::Util qw/none/; # well just one :)

use C4::Koha;
use C4::Biblio;
use C4::Items;
use C4::Circulation;
use C4::Auth;
use C4::Output;
use Koha::RecordProcessor;

use Koha::AuthorisedValues;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user (
    {
        template_name   => "opac-basket.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
    }
);

my $bib_list     = $query->param('bib_list');
my $verbose      = $query->param('verbose');

if ($verbose)      { $template->param( verbose      => 1 ); }

my @bibs = split( /\//, $bib_list );
my @results;

my $num = 1;
my $marcflavour = C4::Context->preference('marcflavour');
if (C4::Context->preference('TagsEnabled')) {
	$template->param(TagsEnabled => 1);
	foreach (qw(TagsShowOnList TagsInputOnList)) {
		C4::Context->preference($_) and $template->param($_ => 1);
	}
}

my $borcat = q{};
if ( C4::Context->preference('OpacHiddenItemsExceptions') ) {
    # we need to fetch the borrower info here, so we can pass the category
    my $patron = Koha::Patrons->find($borrowernumber);
    $borcat = $patron ? $patron->categorycode : $borcat;
}

my $record_processor = Koha::RecordProcessor->new({ filters => 'ViewPolicy' });
foreach my $biblionumber ( @bibs ) {
    $template->param( biblionumber => $biblionumber );

    my $dat              = &GetBiblioData($biblionumber);
    next unless $dat;

    # No filtering on the item records needed for the record itself
    # since the only reason item information is grabbed is because of branchcodes.
    my $record = &GetMarcBiblio({ biblionumber => $biblionumber });
    my $framework = &GetFrameworkCode( $biblionumber );
    $record_processor->options({
        interface => 'opac',
        frameworkcode => $framework
    });
    $record_processor->process($record);
    next unless $record;
    my $marcnotesarray   = GetMarcNotes( $record, $marcflavour );
    my $marcauthorsarray = GetMarcAuthors( $record, $marcflavour );
    my $marcsubjctsarray = GetMarcSubjects( $record, $marcflavour );
    my $marcseriesarray  = GetMarcSeries  ($record,$marcflavour);
    my $marcurlsarray    = GetMarcUrls    ($record,$marcflavour);

    # grab all the items...
    my @all_items        = &GetItemsInfo( $biblionumber );

    # determine which ones should be hidden / visible
    my @hidden_items     = GetHiddenItemnumbers({ items => \@all_items, borcat => $borcat });

    # If every item is hidden, then the biblio should be hidden too.
    next if (scalar @all_items >= 1 && scalar @hidden_items == scalar @all_items);

    # copy the visible ones into the items array.
    my @items;
    foreach my $item (@all_items) {
        if ( none { $item->{itemnumber} ne $_ } @hidden_items ) {
            my $reserve_status = C4::Reserves::GetReserveStatus($item->{itemnumber});
            if( $reserve_status eq "Waiting"){ $item->{'waiting'} = 1; }
            if( $reserve_status eq "Reserved"){ $item->{'onhold'} = 1; }
            push @items, $item;
        }
    }

    my $subtitle         = GetRecordValue('subtitle', $record, GetFrameworkCode($biblionumber));

    my $hasauthors = 0;
    if($dat->{'author'} || @$marcauthorsarray) {
      $hasauthors = 1;
    }
    my $collections =
      { map { $_->{authorised_value} => $_->{opac_description} } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => $dat->{frameworkcode}, kohafield => 'items.ccode' } ) };
    my $shelflocations =
      { map { $_->{authorised_value} => $_->{opac_description} } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => $dat->{frameworkcode}, kohafield => 'items.location' } ) };

	# COinS format FIXME: for books Only
        my $coins_format;
        my $fmt = substr $record->leader(), 6,2;
        my $fmts;
        $fmts->{'am'} = 'book';
        $dat->{ocoins_format} = $fmts->{$fmt};

    if ( $num % 2 == 1 ) {
        $dat->{'even'} = 1;
    }

    for my $itm (@items) {
        if ($itm->{'location'}){
            $itm->{'location_opac'} = $shelflocations->{$itm->{'location'} };
        }
        my ( $transfertwhen, $transfertfrom, $transfertto ) = GetTransfers($itm->{itemnumber});
        if ( defined( $transfertwhen ) && $transfertwhen ne '' ) {
             $itm->{transfertwhen} = $transfertwhen;
             $itm->{transfertfrom} = $transfertfrom;
             $itm->{transfertto}   = $transfertto;
        }
    }
    $num++;
    $dat->{biblionumber} = $biblionumber;
    $dat->{ITEM_RESULTS}   = \@items;
    $dat->{MARCNOTES}      = $marcnotesarray;
    $dat->{MARCSUBJCTS}    = $marcsubjctsarray;
    $dat->{MARCAUTHORS}    = $marcauthorsarray;
    $dat->{MARCSERIES}  = $marcseriesarray;
    $dat->{MARCURLS}    = $marcurlsarray;
    $dat->{HASAUTHORS}  = $hasauthors;
    $dat->{subtitle} = $subtitle;

    if ( C4::Context->preference("BiblioDefaultView") eq "normal" ) {
        $dat->{dest} = "opac-detail.pl";
    }
    elsif ( C4::Context->preference("BiblioDefaultView") eq "marc" ) {
        $dat->{dest} = "opac-MARCdetail.pl";
    }
    else {
        $dat->{dest} = "opac-ISBDdetail.pl";
    }
    push( @results, $dat );
}

my $resultsarray = \@results;

# my $itemsarray=\@items;

$template->param(
    bib_list => $bib_list,
    BIBLIO_RESULTS => $resultsarray,
);

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
