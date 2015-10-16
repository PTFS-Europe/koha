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
        template_name   => 'cm/tillctrl.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $userenv = C4::Context->userenv;

my $user           = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname     = $userenv->{branchname};
my @selected_tills = $q->param('selected_till');
my $till_count     = @selected_tills;
my $cmd            = $q->param('cmd');

my $tills = get_tills( $userenv->{branch} );

my $total_paid_in  = 0;
my $total_paid_out = 0;
my $transactions   = [];
my $popup          = 0;
$popup = $q->param('popup');
my $select_error = 0;
if ( $till_count == 0 && $cmd eq 'cashup' ) {
    $cmd          = 'select';
    $popup        = 1;
    $select_error = 1;
}

if ( $till_count && $cmd eq 'cashup' ) {

    my $cashtime = get_tran_totals(@selected_tills);
    record_cashup( $cashtime, @selected_tills );
}
else {
    $popup = '1';
    $template->param( tills => $tills );
}

$template->param(
    branchname   => $branchname,
    popup        => $popup,
    select_error => $select_error,
);

output_html_with_http_headers( $q, $cookie, $template->output );

sub get_tills {
    my ($branch) = @_;
    my $schema = Koha::Database->new()->schema;
    my @all_tills =
      $schema->resultset('CashTill')->search( { branch => $branch } );
    return \@all_tills;
}

sub get_tran_totals {
    my (@tills)      = @_;
    my $cashup_times = [];
    my $dbh          = C4::Context->dbh;

    my $arr_ref     = $dbh->selectall_arrayref('select NOW()');
    my $cashup_time = $arr_ref->[0]->[0];

    my $tcodes = $dbh->selectall_arrayref(
        'select * from cash_transcode order by code asc',
        { Slice => {} } );
    my %transcodes;
    foreach my $t ( @{$tcodes} ) {
        $t->{total} = 0;
        $transcodes{ $t->{code} } = $t;
    }
    my $card_total = 0;
    my $sql =
q{select max(created) from cash_transaction where till = ? and tcode = 'CASHUP'};
    my $trans_sth = $dbh->prepare(
'select sum(amt) as total, tcode from cash_transaction where till = ? and created > ? and created <= ? group by tcode'
    );
    my $card_sth = $dbh->prepare(
q{select sum(amt) from cash_transaction where till = ? and paymenttype = 'Card' and created > ? and created <= ?}
    );
    my $float_sth =
      $dbh->prepare(q{select starting_float from cash_till where tillid = ?});
    my $sth = $dbh->prepare($sql);
    foreach my $till (@tills) {

        # get last cashupfloat
        $sth->execute($till);
        my @tuple = $sth->fetchrow_array;

        my $last_cash_up = $tuple[0];
        $trans_sth->execute( $till, $last_cash_up, $cashup_time );
        my $totals = $trans_sth->fetchall_arrayref( {} );
        $card_sth->execute( $till, $last_cash_up, $cashup_time );
        my @arr  = $card_sth->fetchrow_array();
        my $card = shift @arr;
        $card ||= 0;

        # contribute to totals table
        foreach my $tuple ( @{$totals} ) {
            $transcodes{ $tuple->{tcode} }->{total} += $tuple->{total};
        }
        $card_total += $card;
        my $float;
        ($float) = $dbh->selectrow_array( $float_sth, {}, $till );
        push @{$cashup_times},
          {
            till  => $till,
            start => $last_cash_up,
            stop  => $cashup_time,
            float => $float,
          };
    }
    my $total  = 0;
    my $tarray = [];

    # Prepare total line & transcation totals
    foreach my $t ( sort keys %transcodes ) {
        if ( $t eq 'CASHUP' || $t eq 'FLOAT' ) {
            next;
        }
        if ( $transcodes{$t}->{total} == 0 ) {
            next;
        }
        push @{$tarray}, $transcodes{$t};
        $total += $transcodes{$t}->{total};
    }

    # pass $tarray $total $card
    $template->param(
        total_array    => $tarray,
        total_receipts => $total,
        card_receipts  => $card_total,
        tilltimes      => $cashup_times,
    );
    return $cashup_time;
}

sub record_cashup {
    my ( $last_transaction_created, @tills ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        'insert into cash_transaction ( created, till, tcode) values(?,?,?)');
    for my $till (@tills) {
        $sth->execute( $last_transaction_created, $till, 'CASHUP' );
    }
    return;
}
