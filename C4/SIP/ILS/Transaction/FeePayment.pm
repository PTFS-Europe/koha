package ILS::Transaction::FeePayment;

use warnings;
use strict;
use Koha::Till;
use Sys::Syslog qw(syslog);


# Copyright 2011 PTFS-Europe Ltd.
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
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use C4::Accounts qw(recordpayment);
use ILS;
use parent qw(ILS::Transaction);


our $debug   = 0;
our $VERSION = 3.07.00.049;

my %fields = ();

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    foreach ( keys %fields ) {
        $self->{_permitted}->{$_} = $fields{$_};    # overlaying _permitted
    }

    @{$self}{ keys %fields } = values %fields;    # copying defaults into object
    return bless $self, $class;
}

sub pay {
    my $self           = shift;
    my $borrowernumber = shift;
    my $amt            = shift;
    my $type           = shift;
    my $tillid         = shift;
    my $koha_paytype;
    syslog('LOG_INFO',"pay:$borrowernumber:$amt:$type:$tillid");

    if ( $type eq '00' ) {
        $koha_paytype = 'Cash';
    }
    elsif ( $type =~m/^0[12]$/) {
        $koha_paytype = 'Card';
    }
    syslog('LOG_INFO',"recordpayment:$borrowernumber:$amt:$type:$tillid:$koha_paytype");
    #warn("RECORD:$borrowernumber::$amt");
    recordpayment( $borrowernumber, $amt, $type, 'sip', $tillid, $koha_paytype, q{} );
    return;
}

#sub DESTROY {
#}

1;
__END__

