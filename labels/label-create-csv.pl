#!/usr/bin/perl

# Copyright Koha development team 2011
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
#

use Modern::Perl;

use CGI qw ( -utf8 );
use Text::CSV_XS;

use C4::Labels;
use C4::Auth qw( check_cookie_auth );

my $cgi = CGI->new;
my ($auth_status) =
    check_cookie_auth( $cgi->cookie('CGISESSID'), { catalogue => 1 } );
if ( $auth_status ne "ok" ) {
    print $cgi->header( -type => 'text/plain', -status => '403 Forbidden' );
    exit 0;
}

my $batch_id;
my @label_ids;
my @item_numbers;
$batch_id = $cgi->param('batch_id') if $cgi->param('batch_id');
my $template_id = $cgi->param('template_id') || undef;
my $layout_id   = $cgi->param('layout_id')   || undef;
@label_ids    = $cgi->multi_param('label_id')    if $cgi->param('label_id');
@item_numbers = $cgi->multi_param('item_number') if $cgi->param('item_number');

my $items = undef;

my $csv_file =
    ( @label_ids || @item_numbers ? "label_single_" . scalar( @label_ids || @item_numbers ) : "label_batch_$batch_id" );
print $cgi->header(
    -type       => 'application/vnd.sun.xml.calc',
    -encoding   => 'utf-8',
    -attachment => "$csv_file.csv",
);

my $batch    = C4::Labels::Batch->retrieve( batch_id => $batch_id );
my $template = C4::Labels::Template->retrieve( template_id => $template_id, profile_id => 1 );
my $layout   = C4::Labels::Layout->retrieve( layout_id => $layout_id );

if (@label_ids) {
    my $batch_items = $batch->get_attr('items');
    grep {
        my $label_id = $_;
        push( @{$items}, grep { $_->{'label_id'} == $label_id; } @{$batch_items} );
    } @label_ids;
} elsif (@item_numbers) {
    grep { push( @{$items}, { item_number => $_ } ); } @item_numbers;
} else {
    $items = $batch->get_attr('items');
}

my $csv = Text::CSV_XS->new( { formula => "empty" } );

foreach my $item (@$items) {
    my $label = C4::Labels::Label->new(
        batch_id      => $batch_id,
        item_number   => $item->{'item_number'},
        format_string => $layout->get_attr('format_string'),
    );
    my $csv_fields = $label->csv_data();
    if ( $csv->combine(@$csv_fields) ) {
        print $csv->string() . "\n";
    } else {
        warn sprintf( 'Text::CSV_XS->combine() returned the following error: %s', $csv->error_input );
    }
}

__END__

=head1 NAME

labels/label-create-csv.pl - A script for creating a csv export of labels and label batches in Koha

=head1 ABSTRACT

This script provides the means of producing a csv of labels for items either individually, in groups, or in batches from within Koha.

=head1 AUTHOR

Chris Nighswonger <cnighswonger AT foundations DOT edu>

=head1 COPYRIGHT

Copyright 2009 Foundations Bible College.

=head1 LICENSE

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Koha is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Koha; if not, see <http://www.gnu.org/licenses>.

=head1 DISCLAIMER OF WARRANTY

Koha is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=cut
