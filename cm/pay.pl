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
use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Database;
use C4::Members qw( GetMember );
use C4::Branch qw( GetBranchName );
use Koha::Till;

my $q = CGI->new();
my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/pay.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $user = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname = GetBranchName( $user->{branchcode} );

my $tillid = $q->param('tillid') || $q->cookie('KohaStaffClient');
my $schema = Koha::Database->new()->schema();

my $chrg_cmd = $q->param('charge');
if ( $chrg_cmd eq 'Charge' ) {
    do_payment();
}
my @payment_types =
  $schema->resultset('AuthorisedValue')
  ->search( { category => 'PaymentType', } );

@payment_types = map { $_->authorised_value } @payment_types;

my @transcodes = $schema->resultset('CashTranscode')
  ->search( { visible_charge => 1 }, { order_by => { -asc => 'code', } } );

# kludge we need to add a typr col so we can select only charges
@transcodes = grep { $_ if ( $_->code ne 'CASHUP' ) } @transcodes;

$template->param(
    branchname   => $branchname,
    tillid       => $tillid,
    paymenttypes => \@payment_types,
    transcodes   => \@transcodes,
);

output_html_with_http_headers( $q, $cookie, $template->output );

sub do_payment {
    my $amt         = $q->param('amt');
    my $paymenttype = $q->param('paymenttype');
    my $trans_code  = $q->param('trans_code');

    # commit a transaction
    my $new_trans = $schema->resultset('CashTransaction')->create(
        {
            amt         => $amt,
            till        => $tillid,
            tcode       => $trans_code,
            paymenttype => $paymenttype,
        }
    );
    return;
}
