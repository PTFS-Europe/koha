#!/usr/bin/perl

# Copyright PTFS Europe 2021
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

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
use C4::Koha qw( getitemtypeimagelocation getitemtypeimagesrc );
use C4::Circulation qw( GetBranchItemRule GetTransfers );
use C4::Reserves qw( CanItemBeReserved CanBookBeReserved AddReserve GetReservesControlBranch IsAvailableForItemLevelRequest );
use C4::Biblio qw( GetBiblioData GetFrameworkCode GetMarcBiblio );
use C4::Items qw( GetHostItemsInfo GetItemsInfo );
use C4::Output qw( output_html_with_http_headers );
use C4::Context;
use C4::Members;
use C4::Overdues;

use Koha::AuthorisedValues;
use Koha::Biblios;
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::CirculationRules;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Checkouts;
use Koha::Libraries;
use Koha::Patrons;
use List::MoreUtils qw( uniq );

my $maxreserves = C4::Context->preference("maxreserves");

my $query = CGI->new;

# if RequestOnOpac (for placing holds) is disabled, leave immediately
if ( ! C4::Context->preference('RequestOnOpac') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-booking.tt",
        query           => $query,
        type            => "opac",
    }
);

my $patron = Koha::Patrons->find( $borrowernumber, { prefetch => ['categorycode'] } );
my $category = $patron->category;

my $biblionumber = $query->param('biblionumber');

if ( $query->param('place_booking') ) {

}

output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
