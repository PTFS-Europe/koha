#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2012 ByWater Solutions
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
use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Members;
use C4::Suggestions;
use Koha::Patrons;

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   template_name   => "members/purchase-suggestions.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { suggestions => 'suggestions_manage' },
        debug           => 1,
    }
);

my $borrowernumber = $input->param('borrowernumber');

my $logged_in_user = Koha::Patrons->find( $loggedinuser );
my $patron         = Koha::Patrons->find( $borrowernumber );
output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

my $category = $patron->category;
$template->param(
    patron => $patron,
    suggestionsview  => 1,
);

my $suggestions = SearchSuggestion( { suggestedby => $borrowernumber } );

$template->param( suggestions => $suggestions );

    my @relatives;
    my $guarantor_relationships = $patron->guarantor_relationships;
    my @guarantees              = $patron->guarantee_relationships->guarantees;
    my @guarantors              = $guarantor_relationships->guarantors;
    if (@guarantors) {
               push( @relatives, $_->id ) for @guarantors;
                   push( @relatives, $_->id ) for $patron->siblings();
           }
           else {
                       push( @relatives, $_->id ) for @guarantees;
               }
$template->param(
           guarantor_relationships => $guarantor_relationships,
               guarantees              => \@guarantees,
       );

output_html_with_http_headers $input, $cookie, $template->output;
