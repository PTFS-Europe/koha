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
use CGI;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::Context;
use Koha::Database;
use C4::Members qw( GetMember );
use C4::Branch qw( GetBranchName );
use Koha::Till;

my $q         = CGI->new();
my $sessionID = $q->cookie('CGISESSID');
my $session   = get_session($sessionID);

my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/pay.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);
my $branch = $q->param('branch') || $session->param('branch');

my $user = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname = GetBranchName($branch);

my $tillid = $q->param('tillid');
if ( !$tillid ) {
    $tillid = $session->param('tillid') || Koha::Till->branch_tillid($branch);
}
our $schema = Koha::Database->new()->schema();

my $command = $q->param('cmd');

if ( $command && $command eq 'committrans' ) {
    do_payment($q);
}

my @payment_types =
  $schema->resultset('AuthorisedValue')
  ->search( { category => 'PaymentType', } );
my @tills = $schema->resultset('CashTill')->all();

@payment_types = map { $_->authorised_value } @payment_types;

my @transcodes = $schema->resultset('CashTranscode')->search(
    { visible_charge => 1, archived => 0 },
    { order_by => { -asc => 'code', } }
);

# kludge we need to add a typr col so we can select only charges
@transcodes = grep { $_ if ( $_->code ne 'CASHUP' ) } @transcodes;
my $timestamp = time;

$template->param(
    branchname   => $branchname,
    tillid       => $tillid,
    tills        => \@tills,
    paymenttypes => \@payment_types,
    transcodes   => \@transcodes,
    paymenttime  => $timestamp,
);

output_html_with_http_headers( $q, $cookie, $template->output );

sub do_payment {
    my $cgi = shift;
    my @amounts = split /,/, $cgi->param('amounts');
    my @codes   = split /,/, $cgi->param('codes');

    my $paymenttype = $cgi->param('paymenttype');
    my $paymenttime = $cgi->param('paymenttime');

    my $receiptid = "$tillid-$paymenttime";

    foreach my $amt (@amounts) {
        my $trans_code = shift @codes;

        # commit a transaction
        my $new_trans = $schema->resultset('CashTransaction')->create(
            {
                amt         => $amt,
                till        => $tillid,
                tcode       => $trans_code,
                paymenttype => $paymenttype,
                receiptid   => $receiptid,
            }
        );
    }
    return;
}
