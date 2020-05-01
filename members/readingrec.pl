#!/usr/bin/perl

# written 27/01/2000
# script to display borrowers reading record

# Copyright 2000-2002 Katipo Communications
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
use C4::Output;
use C4::Members;
use List::MoreUtils qw/any uniq/;
use Koha::DateUtils;

use Koha::Patrons;
use Koha::Patron::Categories;

my $input = CGI->new;

my ($template, $loggedinuser, $cookie)= get_template_and_user({template_name => "members/readingrec.tt",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
                flagsrequired => {borrowers => 'edit_borrowers'},
				debug => 1,
				});

my $op = $input->param('op') || '';
my $patron;
if ($input->param('cardnumber')) {
    my $cardnumber = $input->param('cardnumber');
    $patron = Koha::Patrons->find( { cardnumber => $cardnumber } );
}
if ($input->param('borrowernumber')) {
    my $borrowernumber = $input->param('borrowernumber');
    $patron = Koha::Patrons->find( $borrowernumber );
}

my $logged_in_user = Koha::Patrons->find( $loggedinuser );
output_and_exit_if_error( $input, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

my $order = 'date_due desc';
my $limit = 0;
my $issues = ();
# Do not request the old issues of anonymous patron
if ( $patron->borrowernumber eq C4::Context->preference('AnonymousPatron') ){
    # use of 'eq' in the above comparison is intentional -- the
    # system preference value could be blank
    $template->param( is_anonymous => 1 );
} else {
    $issues = GetAllIssues($patron->borrowernumber,$order,$limit);
}

#   barcode export
if ( $op eq 'export_barcodes' ) {
    # FIXME This should be moved out of this script
    if ( $patron->privacy < 2) {
        my $today = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
        my @barcodes =
          map { $_->{barcode} } grep { $_->{returndate} =~ m/^$today/o } @{$issues};
        my $borrowercardnumber = $patron->cardnumber;
        my $delimiter = "\n";
        binmode( STDOUT, ":encoding(UTF-8)" );
        print $input->header(
            -type       => 'application/octet-stream',
            -charset    => 'utf-8',
            -attachment => "$today-$borrowercardnumber-checkinexport.txt"
        );

        my $content = join $delimiter, uniq(@barcodes);
        print $content;
        exit;
    }
}

if (! $limit){
	$limit = 'full';
}

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
my $relatives_issues_count =
  Koha::Database->new()->schema()->resultset('Issue')
  ->count( { borrowernumber => \@relatives } );

$template->param(
    patron            => $patron,
    readingrecordview => 1,
    loop_reading      => $issues,
);
output_html_with_http_headers $input, $cookie, $template->output;

