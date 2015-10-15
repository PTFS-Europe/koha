#!/usr/bin/perl
#
# c 2015 PTFS-Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA
#

use Modern::Perl;
use DateTime;

use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Branch qw( GetBranches );
use CGI;
use Koha::DateUtils;
use Koha::Till;
use List::Util qw( sum );

my $input = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'cm/printreceipt.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $now        = DateTime->now();
my $env        = C4::Context->userenv;
my $change     = $input->param('change');
my $tendered   = $input->param('tendered');
my @amounts    = split /,/, $input->param('amounts');
my @transcodes = split /,/, $input->param('transcodes');
my $tillid     = $input->param('tillid');
if ( !$tillid ) {
    my $sessionID = $input->cookie('CGISESSID');
    my $session   = get_session($sessionID);
    $tillid = $session->param('tillid')
      || Koha::Till->branch_tillid( $session->param('branch') );
}

my $timestamp = $input->param('paymenttime');

my %tc_desc = get_transcode_descriptions();

my $receiptrows = [];    # this is for the tmpl-loop
foreach my $amt (@amounts) {
    my $transcode = shift @transcodes;

    push @{$receiptrows},
      {
        description => $tc_desc{$transcode},
        amount      => $amt,
      };
}

my $total = sum @amounts;

my $receiptid = "${tillid}-$timestamp";

$template->param(
    branchcode => $env->{branch},
    branchname => $env->{branchname},
    datetime   => output_pref($now),

    total     => sprintf( '%.2f', $total ),
    change    => $change,
    tendered  => $tendered,
    receipts  => $receiptrows,
    receiptid => $receiptid
);

output_html_with_http_headers $input, $cookie, $template->output;

sub get_transcode_descriptions {
    my $dbh = C4::Context->dbh;
    my $tc =
      $dbh->selectall_arrayref('select code, description from cash_transcode');
    my %descriptions = map { $_->[0] => $_->[1] } @{$tc};
    return %descriptions;
}
