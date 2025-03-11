#!/usr/bin/perl

# Copyright 2024 PTFS Europe
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use Modern::Perl;
use DateTime;

use Koha::Script -cron;
use C4::Context;
use Koha::Acquisition::Basket;
use Koha::Database;
use Koha::Logger;

die "Syspref 'EDIFACT' is disabled" unless C4::Context->preference('EDIFACT');

my $schema = Koha::Database->new()->schema();

process_quotes();

sub process_quotes {
    my $today    = DateTime->now->ymd;
    my $messages = $schema->resultset('EdifactMessage')->search(
        {
            message_type => 'QUOTE',
            status       => { '-in' => [ 'received', 'recmsg' ] }
        }
    );

    while ( my $message = $messages->next ) {
        my $basket_rs = $message->basketno;
        my $basket    = Koha::Acquisition::Basket->_new_from_dbic($basket_rs);

        my $orders = $basket->orders;
        while ( my $order = $orders->next ) {

            my $vendor_note = $order->order_vendornote;

            # Process fields quoted by '$'
            # Subject fund -> sort1
            if ( my @matches = $vendor_note =~ /\$(.*?)\$/g ) {
                if ( @matches > 1 ) {
                    warn "Multiple fields quoted by \$ found: @matches\n";
                } else {
                    my $sort1 = $matches[0];
                    $order->sort1($sort1);
                }
            }

            # Process fields quoted by '^'
            # Internal reference -> order_internalnote
            if ( my @matches = $vendor_note =~ /\^(.*?)\^/g ) {
                if ( @matches > 1 ) {
                    warn "Multiple fields quoted by ^ found: @matches\n";
                } else {
                    my $order_internalnote =
                        $order->order_internalnote ? $order->order_internalnote . ' ' . $matches[0] : $matches[0];
                    $order->order_internalnote($order_internalnote);
                }
            }

            # Process fields quoted by '!'
            # Notes to ASM -> order_internalnote
            if ( my @matches = $vendor_note =~ /!(.*?)!/g ) {
                if ( @matches > 1 ) {
                    warn "Multiple fields quoted by ^ found: @matches\n";
                } else {
                    my $order_internalnote =
                        $order->order_internalnote ? $order->order_internalnote . ' ' . $matches[0] : $matches[0];
                    $order->order_internalnote($order_internalnote);
                }
            }

            # Process fields quoted by '#'
            # Purhchase reason -> sort2
            if ( my @matches = $vendor_note =~ /\#(.*?)\#/g ) {
                if ( @matches > 1 ) {
                    warn "Multiple fields quoted by # found: @matches\n";
                } else {
                    my $sort2 = $matches[0];
                    $order->sort2($sort2);
                }
            }

            $order->store();
        }

        my $status = 'post-' . $message->status;
        $message->status($status);
        $message->update;
    }
}
