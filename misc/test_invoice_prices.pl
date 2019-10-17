#!/usr/bin/perl
use strict;
use warnings;
use feature qw( say );
use C4::Context;
use Koha::Edifact;
use File::Slurp qw(read_file);

my $invoice_file = shift;

my $file_contents = read_file($invoice_file);

my $edi = Koha::Edifact->new( { transmission => $file_contents, } );

my $messages = $edi->message_array();

foreach my $msg ( @{$messages} ) {
    my $invoicenumber = $msg->docmsg_number();

    say "Invoice:$invoicenumber";

    my $lines          = $msg->lineitems();
    my $total          = 0;
    my $total_excl_tax = 0;
    my $items          = 0;

    foreach my $line ( @{$lines} ) {
        my $ordernumber = $line->ordernumber;
        my $qty         = $line->quantity;
        print "ORD:$ordernumber\tQTY:$qty\t";
        my $line_total = $line->amt_total;
        my $excl_tax   = $line->amt_lineitem;
        if ( !defined $line_total ) {
            my $x = $line->amt_taxoncharge;
            if ( !defined $x ) {
                $x = 0;
            }

            $line_total = $excl_tax + $x;
        }

        # If no tax some suppliers omit the total owed
        $total          += $line_total;
        $total_excl_tax += $excl_tax;
        $items          += $qty;

        my $item_price   = $line_total / $qty;
        my $pri_excl_tax = $excl_tax / $qty;

        say "$line_total\t$excl_tax\t($item_price,$pri_excl_tax)";
    }
    say
"\nTotal for Invoice:$total\tExcluding Tax:$total_excl_tax\t$items items\n";

    # get totals from Invoice Summary
    say 'Totals from Message Summary:';
    $msg->summary();
    say q{};
}

