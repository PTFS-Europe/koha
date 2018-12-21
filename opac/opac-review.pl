#!/usr/bin/perl

# Copyright 2006 Katipo Communications
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
use C4::Auth;
use C4::Koha;
use C4::Output;
use C4::Biblio;
use C4::Scrubber;
use C4::Debug;

use Koha::Biblios;
use Koha::DateUtils;
use Koha::Review;
use Koha::Reviews;

my $query        = new CGI;
my $biblionumber = $query->param('biblionumber');
my $review       = $query->param('review');
my $reviewid     = $query->param('reviewid');
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-review.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => ( C4::Context->preference("OpacPublic") ? 1 : 0 ),
    }
);

# FIXME: need to allow user to delete their own comment(s)

my ( $clean, @errors, $savedreview );
my $biblio = Koha::Biblios->find( $biblionumber );

if( !$biblio ) {
    push @errors, { nobiblio => 1 };
} elsif( $reviewid ) { # edit existing one, check on creator
    $savedreview = Koha::Reviews->search({ reviewid => $reviewid, borrowernumber => $borrowernumber })->next;
    push @errors, { unauthorized => 1 } if !$savedreview;
} else { # this check prevents adding multiple comments
    # FIXME biblionumber, borrowernumber should be a unique key of reviews
    $savedreview = Koha::Reviews->search({ biblionumber => $biblionumber, borrowernumber => $borrowernumber })->next;
    $review = $savedreview? $savedreview->review: $review;
}

if( !@errors && defined $review ) {
	if ($review !~ /\S/) {
		push @errors, {empty=>1};
	} else {
		$clean = C4::Scrubber->new('comment')->scrub($review);
		if ($clean !~ /\S/) {
			push @errors, {scrubbed_all=>1};
		} else {
			if ($clean ne $review) {
				push @errors, {scrubbed=>$clean};
			}
            if ($savedreview) {
                $savedreview->set(
                    {
                        review        => $clean,
                        approved      => 0,
                        datereviewed  => dt_from_string
                    }
                )->store;
            } else {
                $reviewid = Koha::Review->new(
                    {   biblionumber   => $biblionumber,
                        borrowernumber => $borrowernumber,
                        review         => $clean,
                        datereviewed   => dt_from_string
                    }
                )->store->reviewid;
            }
			unless (@errors){ $template->param(WINDOW_CLOSE=>1); }
		}
	}
}
(@errors   ) and $template->param(   ERRORS=>\@errors);
($cgi_debug) and $template->param(cgi_debug=>1       );
$review = $clean;
$review ||= $savedreview->review if $savedreview;
$template->param(
    'biblionumber'   => $biblionumber,
    'borrowernumber' => $borrowernumber,
    'review'         => $review,
    'reviewid'       => $reviewid || 0,
    'title'          => $biblio->title,
);

output_html_with_http_headers $query, $cookie, $template->output;
