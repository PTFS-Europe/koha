#!/usr/bin/perl

# Copyright 2019 PTFS Europe
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

=head1 NAME

modordernotes_multiple.pl

=head1 DESCRIPTION

Modify multiple order notes

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Acquisition;

use Koha::Acquisition::Booksellers;

my $input = new CGI;
my ($template, $loggedinuser, $cookie, $flags) = get_template_and_user( {
    template_name   => 'acqui/modordernotes.tt',
    query           => $input,
    type            => 'intranet',
    authnotrequired => 0,
    flagsrequired   => { 'acquisition' => '*' },
    debug           => 1,
} );

my $orders_all_str = $input->param('orders_all');
my $orders_modified_str = $input->param('orders_modified');
my @orders_all = split(',',$orders_all_str);
my %orders_modified = map { $_ => 1 } split(',',$orders_modified_str);
my $note = $input->param('note') && length $input->param('note') > 0 ?
    $input->param('note') :
    undef;
my $referrer = $input->param('referrer') || $input->referer();
my $type = $input->param('type');

if (scalar @orders_all > 0) {
    foreach my $ordernumber(@orders_all) {
        my $final_note = exists $orders_modified{$ordernumber} ? $note : undef;
        modifyOrder({
            ordernumber => $ordernumber,
            note        => $final_note,
            type        => $type
        });
    }
}

print $input->redirect($referrer);
exit;

sub modifyOrder {
    my $params = shift;

    my $order = GetOrder($params->{ordernumber});
    my $basket = GetBasket($order->{basketno});
    if ($params->{type} eq "vendor") {
        $order->{'order_vendornote'} = $params->{note};
    } else {
        $order->{'order_internalnote'} = $params->{note};
    }
    ModOrder($order);
};
