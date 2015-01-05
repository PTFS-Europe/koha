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
use List::Util qw(sum);

my $q = CGI->new();
my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/till.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $user = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname = GetBranchName( $user->{branchcode} );

my $schema = Koha::Database->new()->schema;

my $till = get_till( $schema, $q );
my $date;
my $cmd = $q->param('cmd');
$cmd ||= 'display';
if ( $cmd eq 'all' ) {
    $cmd = 'display',;
}
elsif ( $cmd eq 'day' ) {
    $date = $q->param->('date');
}
elsif ( $cmd eq 'cashup' ) {
    my $ctrl_rec = $schema->resultset('CashTransaction')->create(
        {
            till  => $till->tillid(),
            tcode => 'CASHUP',
        }
    );
}
elsif ( $cmd eq 'addfloat' ) {
    my $float_amt = $q->param('floatamt');
    my $ctrl_rec  = $schema->resultset('CashTransaction')->create(
        {
            till  => $till->tillid(),
            tcode => 'FLOAT',
            amt   => $float_amt,
        }
    );
}

my $total_paid_in;
my $total_paid_out;
my $transactions;
my $popup = 0;

if ($till) {
    $transactions = get_transactions( $till->tillid(), $cmd, $date );
    my $count = @{$transactions};

    $total_paid_in  = sum map { $_->{amt} if $_->{amt} > 0 } @{$transactions};
    $total_paid_out = sum map { $_->{amt} if $_->{amt} < 0 } @{$transactions};
    $total_paid_in  ||= 0;
    $total_paid_out ||= 0;

    if ( $cmd eq 'cashup' ) {

        my $subtotals     = [];
        my @payment_types = $schema->resultset('AuthorisedValue')
          ->search( { category => 'PaymentType', } )->all();
        foreach my $pt (@payment_types) {
            my $type = $pt->authorised_value;
            my $sum_in =
              sum
              map { $_->{amt} if $_->{paymenttype} eq $type && $_->{amt} > 0 }
              @{$transactions};
            my $sum_out =
              sum
              map { $_->{amt} if $_->{paymenttype} eq $type && $_->{amt} < 0 }
              @{$transactions};
            $sum_in  ||= 0;
            $sum_out ||= 0;

            push @{$subtotals},
              {
                type    => $type,
                in      => $sum_in,
                out     => $sum_out,
                balance => $sum_in + $sum_out,
              };
        }

        $template->param(
            subtotals => $subtotals,
            cashup    => 1,
        );
    }
}
else {
    $popup = '1';
}

$template->param(
    branchname   => $branchname,
    till         => $till,
    transactions => $transactions,
    total_in     => $total_paid_in,
    total_out    => $total_paid_out,
    balance      => $total_paid_in + $total_paid_out,    # paid_out is neg
    popup        => $popup,
);

output_html_with_http_headers( $q, $cookie, $template->output );

sub get_till {
    my ( $schema, $cgi_query ) = @_;

    my $id = $cgi_query->param('tillid');
    $id ||= $cgi_query->cookie('KohaStaffClient');

    if ($id) {
        return $schema->resultset('CashTill')->find($id);
    }

    my $rs = $schema->resultset('CashTill')->search( { tillid => $id } );
    return $rs->single;
}

sub get_transactions {
    my ( $till, $cmd, $date ) = @_;
    my $sql;
    my @query_parameters;

    if ( $cmd eq 'display' || $cmd eq 'cashup' ) {
        $sql =
'select * from cash_transaction where till = ? and datediff( created, NOW()) = 0 order by created';
        @query_parameters = ($till);
    }
    elsif ( $cmd eq 'day' )
    {    # show transactions for a specific date ( not today )
        $sql =
'select * from cash_transaction where till = ? and DATE( created) = ? order by created';
        @query_parameters = ( $till, $date );
    }
    my $dbh = C4::Context->dbh;

    return $dbh->selectall_arrayref( $sql, { Slice => {} }, @query_parameters );
}
