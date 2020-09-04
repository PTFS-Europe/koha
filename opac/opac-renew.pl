#!/usr/bin/perl

#written 18/1/2000 by chris@katipo.co.nz
# adapted for use in the hlt opac by finlay@katipo.co.nz 29/11/2002
# script to renew items from the web
# Parts Copyright 2010,2011 Catalyst IT

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
use C4::Circulation;
use C4::Auth;
use C4::Context;
use C4::Items;
use C4::Members;
use Koha::Items;
use Koha::Patrons;
use Date::Calc qw( Today Date_to_Days );
my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
	{
        template_name   => "opac-user.tt",
        query           => $query,
        type            => "opac",
        debug           => 1,
	}
); 
my @items = $query->multi_param('item');

my $opacrenew = C4::Context->preference("OpacRenewalAllowed");

my $errorstring = q{};
my $renewed     = q{};

my $patron = Koha::Patrons->find( $borrowernumber );

if (   $patron->category->effective_BlockExpiredPatronOpacActions
    && $patron->is_expired )
{
    $errorstring = 'card_expired';
}
else {
    my @renewed;
    for my $itemnumber (@items) {
        my ( $status, $error ) =
          CanBookBeRenewed( $borrowernumber, $itemnumber );
        if ( $status == 1 && $opacrenew == 1 ) {
            my $renewalbranch = C4::Context->preference('OpacRenewalBranch');
            my $branchcode;
            if ( $renewalbranch eq 'itemhomebranch' ) {
                my $item = Koha::Items->find($itemnumber);
                $branchcode = $item->homebranch;
            }
            elsif ( $renewalbranch eq 'patronhomebranch' ) {
                $branchcode = Koha::Patrons->find( $borrowernumber )->branchcode;
            }
            elsif ( $renewalbranch eq 'checkoutbranch' ) {
                my $issue = GetOpenIssue($itemnumber); # FIXME Should not be $item->checkout?
                $branchcode = $issue->{'branchcode'};
            }
            elsif ( $renewalbranch eq 'NULL' ) {
                $branchcode = '';
            }
            else {
                $branchcode = 'OPACRenew';
            }
            AddRenewal( $borrowernumber, $itemnumber, $branchcode, undef, undef, 0 );
            push( @renewed, $itemnumber );
        }
        else {
            $errorstring .= $error . "|";
        }
    }
    $renewed = join( ':', @renewed );
}

print $query->redirect("/cgi-bin/koha/opac-user.pl?renew_error=$errorstring&renewed=$renewed");

