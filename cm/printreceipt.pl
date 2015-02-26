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

use C4::Auth;
use C4::Output;
use CGI;
use Koha::Database;
use Koha::DateUtils;

my $input = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "cm/printreceipt.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $now = DateTime->now();
my $session = C4::Context->userenv;
my $change = $input->param('change');
my $tendered = $input->param('tendered');
my @amounts = split /,/, $input->param('amounts');
my @transcodes = split /,/, $input->param('transcodes');
my $tillid = $input->param('tillid') || $input->cookie("KohaStaffClient");
my $timestamp = $input->param('paymenttime');

my $schema = Koha::Database->new()->schema();

my @receiptrows;    # this is for the tmpl-loop
foreach my $amt (@amounts) {
    my $transcode = shift @transcodes;
    warn "Transcode: " . $transcode;
    my $description = $schema->resultset('CashTranscode')->find( { code => $transcode } );

    my %row = (
        'description' => $description->get_column('description'),
        'amount' => $amt,
    );
    push( @receiptrows, \%row );
}

my $total = 0;
for ( @amounts ) {
    $total += $_;
}

my $receiptid = $tillid . "-" . $timestamp;

$template->param(
    branchcode   => $session->{'branch'},
    branchname   => $session->{'branchname'},
    datetime     => output_pref( $now ),

    total        => sprintf( "%.2f", $total ),
    change       => $change,
    tendered     => $tendered,
    receipts     => \@receiptrows,
    receiptid    => $receiptid
);

output_html_with_http_headers $input, $cookie, $template->output;
