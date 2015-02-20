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

my $user           = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname     = GetBranchName( $user->{branchcode} );
my @selected_tills = $q->param('selected_till');
my $till_count     = @selected_tills;
my $cmd            = $q->param('cmd');

my $schema = Koha::Database->new()->schema;

my $tills = get_tills($schema);
my $date;

my $total_paid_in = 0;
my $total_paid_out = 0;
my $transactions = [];
my $popup = 0;
$popup = $q->param('popup');
my $select_error = 0;
if ( $till_count == 0 && $cmd eq 'cashup' ) {
    $cmd          = 'select';
    $popup        = 1;
    $select_error = 1;
}

if ( $till_count && $cmd eq 'cashup' ) {

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        'insert into cash_transaction ( created, till, tcode) values(?,?,?)');
    get_tran_totals(@selected_tills);
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

sub get_tills {
    my $schema    = shift;
    my @all_tills = $schema->resultset('CashTill')->all;
    return \@all_tills;
}

sub get_transactions {
    my ( $till, $cmd, $date ) = @_;
    my $sql;
    my @query_parameters;

    my $dbh = C4::Context->dbh;
    if ( $cmd eq 'cashup' ) {

        # get last cashup
        $sql =
q{select max(created) from cash_transaction where till = ? and tcode = 'CASHUP'};
        my $res_ref = $dbh->selectcol_arrayref( $sql, {}, $till );
        if ( defined $res_ref->[0] ) {
            my $last_cash_up = $res_ref->[0];

            $sql =
'select * from cash_transaction where till = ? and created > ? order by created';
            @query_parameters = ( $till, $last_cash_up );

        }
        else {
            # never cashed up before
            $sql =
              'select * from cash_transaction where till = ? order by created';
            @query_parameters = ($till);
        }
    }
    elsif ( $cmd eq 'display' || $cmd eq 'cashup' ) {
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

    return $dbh->selectall_arrayref( $sql, { Slice => {} }, @query_parameters );
}

sub get_tran_totals {
    my (@tills) = @_;
    my $dbh = C4::Context->dbh;

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
    my $sth = $dbh->prepare($sql);
    foreach my $till (@tills) {

        # get last cashup
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
    }
    my $total  = 0;
    my $tarray = [];

    # Prepare total line & transcation totals
    foreach my $t ( sort keys %transcodes ) {
        if ( $t =~ m/^(CASHUP|FLOAT)$/ ) {
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
    );
    return;
}

sub record_cashup {
    my ( $statement_handle, $till, $last_transaction_created ) = @_;
    $statement_handle->execute( $till, $last_transaction_created );
    return;
}
