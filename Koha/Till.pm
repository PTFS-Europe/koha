package Koha::Till;
use strict;
use warnings;
use Koha::Database;
use Carp;

my $default_transaction_code = 'DEFAULT';

sub new {
    my ( $class, $params ) = @_;

    my $schema   = Koha::Database->new()->schema();
    my $tills_rs = $schema->resultset('CashTill')->search($params);

    if ( $tills_rs->count != 1 ) {
        my $plist = q{};
        foreach my $pkey ( keys %{$params} ) {
            $plist .= " $pkey:$params->{$pkey}";
        }
        carp("Cannot instantiate till ::$plist");

        return;
    }

    my $self = {
        schema  => $schema,
        till_id => $tills_rs->first->tillid,
    };

    bless $self, $class;
    return $self;
}

sub payin {
    my ( $self, $amt, $code, $type, $receiptid ) = @_;

    # IN code will be pos
    # OUT code should be neg
    # EVENT is 0

    # dont refuse the payment if we cant identify a transaction for it
    my $tc_rs = $self->{schema}->resultset('CashTranscode')->search(
        {
            code     => $code,
            archived => 0,
        }
    );
    if ( $tc_rs->count == 0 ) {
        $code = $default_transaction_code;
    }

    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt         => $amt,
            till        => $self->{till_id},
            tcode       => $code,
            paymenttype => $type,
            receiptid   => $receiptid,
        }
      );
    return;
}

sub payout {
    my ( $self, $amt, $code ) = @_;
    $amt *= -1;    # payouts are negative
    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt   => $amt,
            till  => $self->{till_id},
            tcode => $code,
        }
      );

    return;
}

sub ctltrans {
    my ( $self, $code ) = @_;
    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt   => undef,
            till  => $self->{till_id},
            tcode => $code,
        }
      );
    return;
}

sub get_till_list {
    my ( $class, $branch ) = @_;

    # Class method to get a list of tills, if branch passed restrict to
    # unarchived tills of that branch
    my $search_parm = {};
    if ($branch) {
        $search_parm->{branch}   = $branch;
        $search_parm->{archived} = 0;
    }
    my $schema = Koha::Database->new()->schema();
    my @tills  = $schema->resultset('CashTill')->search($search_parm);

    return \@tills;
}

sub branch_tillid {
    my ( $class, $branch ) = @_;

    # return default counter till for branch
    if ( !$branch ) {
        carp('branch_tillid called without a branch value');
        return;
    }
    my $dbh = C4::Context->dbh;
    my ($x) = $dbh->selectrow_array(
        'select default_till  from branches where branchcode = ?',
        {}, $branch );
    if (!$x) {
        carp("branch_tillid unable to return a till for $branch");
    }
    return $x;
}

1;
__END__

=head1 NAME

Koha::Till - Interface To Cash Management for recording payments

=head1 VERSION

This documentation refers to Koha::Till version 0.0.1

=head1 SYNOPSIS

  use Koha::Till;

  my $cm = Koha::Till->new('TILL52');

  $cm->payin(5.00, 'FINE', 'CASH');

=head1 DESCRIPTION

  payments and payouts are recorded via this module. On instantiation the recording till is set

=head1 METHODS

=head2 new  : Create a Till object

my $till = Koha::Till->new('XYZ123');

Create a new Till object, the name of the required till is passed, if no till name is passed the link
is with the DEFAULT till

=head2 payin : Record a payment in the till

  $till->payin($amount, $code, $payment_type)

C<$amount> is the amount paid

C<$code> is the code to be associated with the payment 'FINE', 'FEE', 'PURCHASE'

C<$payment_type> is the payment type 'CASH', 'CHEQUE', 'CARD' etc.

Records the given payment against the associated till

=head2 payout : Extract monies from the till

  $till->payout($amount, $code);

C<$amount> is the amount paid out

C<$code> is the code to be associated with the payment 'REFUND' etc.

=head2 ctltrans : Record a control transacton

   $till->ctltrans($code);

C<$code> code for transaction,

Control transactions have no money amount associated and are used to record
administrative transactions. E.G. a verification of the balance of the physical till


=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Colin Campbell colin.campbell@ptfs-europe.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015 PTFS-Europe Ltd All rights reserved

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
