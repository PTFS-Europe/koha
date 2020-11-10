#!/usr/bin/perl

#script to add an order into the system
#written 29/2/00 by chris@katipo.co.nz

# Copyright 2000-2002 Katipo Communications
#
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

addorder.pl

=head1 DESCRIPTION

this script allows to add an order.
It is called by :

=over

=item neworderbiblio.pl to add an order from nothing.

=item neworderempty.pl to add an order from an existing biblio.

=item newordersuggestion.pl to add an order from an existing suggestion.

=back

=head1 CGI PARAMETERS

All of the cgi parameters below are related to the new order.

=over

=item C<ordernumber>
the number of this new order.

=item C<basketno>
the number of this new basket

=item C<booksellerid>
the bookseller the librarian has to pay.

=item C<existing>

=item C<title>
the title of the record ordered.

=item C<author>
the author of the record ordered.

=item C<copyrightdate>
the copyrightdate of the record ordered.

=item C<ISBN>
the ISBN of the record ordered.

=item C<format>

=item C<quantity>
the quantity to order.

=item C<list_price>
the price of this order.

=item C<uncertainprice>
uncertain price, can't close basket until prices of all orders are known.

=item C<branch>
the branch where this order will be received.

=item C<series>

=item C<notes>
Notes on this basket.

=item C<budget_id>
budget_id used to pay this order.

=item C<sort1> & C<sort2>

=item C<rrp>

=item C<ecost>

=item C<GST>

=item C<budget>

=item C<cost>

=item C<sub>

=item C<invoice>
the number of the invoice for this order.

=item C<publishercode>

=item C<suggestionid>
if it is an order from an existing suggestion : the id of this suggestion.

=item C<donation>

=back

=cut

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth;           # get_template_and_user
use C4::Acquisition;    # ModOrder
use C4::Suggestions;    # ModStatus
use C4::Biblio;         # AddBiblio TransformKohaToMarc
use C4::Budgets;
use C4::Items;
use C4::Output;
use C4::Log qw(logaction);
use Koha::Acquisition::Currencies;
use Koha::Acquisition::Orders;
use C4::Barcodes;

### "-------------------- addorder.pl ----------"

# FIXME: This needs to do actual error checking and possibly return user to the same form,
# not just blindly call C4 functions and print a redirect.  

my $input = new CGI;
my $use_ACQ_framework = $input->param('use_ACQ_framework');

# Check if order total amount exceed allowed budget
my $confirm_budget_exceeding = $input->param('confirm_budget_exceeding');
unless($confirm_budget_exceeding) {
    my $budget_id = $input->param('budget_id');
    my $total = $input->param('total');
    my $budget = GetBudget($budget_id);
    my $budget_spent = GetBudgetSpent($budget_id);
    my $budget_ordered = GetBudgetOrdered($budget_id);
    my $budget_used = $budget_spent + $budget_ordered;
    my $budget_remaining = $budget->{budget_amount} - $budget_used;
    my $budget_encumbrance = $budget->{budget_amount} * $budget->{budget_encumb} / 100;
    my $budget_expenditure = $budget->{budget_expend};

    if ( $total > $budget_remaining
      || ( ($budget_encumbrance+0) && ($budget_used + $total) > $budget_encumbrance)
      || ( ($budget_expenditure+0) && ($budget_used + $total) > $budget_expenditure) )
    {
        my ($template, $loggedinuser, $cookie) = get_template_and_user({
            template_name   => "acqui/addorder.tt",
            query           => $input,
            type            => "intranet",
            flagsrequired   => {acquisition => 'order_manage'},
        });

        my $url = $input->referer();
        unless ( defined $url ) {
            my $basketno = $input->param('basketno');
            $url = "/cgi-bin/koha/acqui/basket.pl?basketno=$basketno";
        }

        my $vars = $input->Vars;
        my @vars_loop;
        foreach (keys %$vars) {
            push @vars_loop, {
                name => $_,
                values => [$input->param($_)],
            };
        }

        if( ($budget_encumbrance+0) && ($budget_used + $total) > $budget_encumbrance
          && $total <= $budget_remaining)
        {
            $template->param(
                encumbrance_exceeded => 1,
                encumbrance => sprintf("%.2f", $budget->{'budget_encumb'}),
            );
        }
        if( ($budget_expenditure+0) && ($budget_used + $total) > $budget_expenditure
          && $total <= $budget_remaining )
        {
            my $currency = Koha::Acquisition::Currencies->get_active;
            $template->param(
                expenditure_exceeded => 1,
                expenditure => sprintf("%.2f", $budget_expenditure),
                currency => ($currency) ? $currency->symbol : '',
            );
        }
        if($total > $budget_remaining){
            $template->param(budget_exceeded => 1);
        }

        $template->param(
            not_enough_budget => 1,
            referer => $url,
            vars_loop => \@vars_loop,
        );
        output_html_with_http_headers $input, $cookie, $template->output;
        exit;
    }
}

# get_template_and_user used only to check auth & get user id
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "acqui/booksellers.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => { acquisition => 'order_manage' },
        debug           => 1,
    }
);

# get CGI parameters
my $orderinfo = $input->Vars;
$orderinfo->{'list_price'}    ||=  0;
$orderinfo->{'uncertainprice'} ||= 0;
$orderinfo->{subscriptionid} ||= undef;

my $user     = $input->remote_user;
my $basketno = $$orderinfo{basketno};
my $basket   = Koha::Acquisition::Baskets->find($basketno);

# Order related fields we're going to log
my @log_order_fields = (
    'quantity',
    'listprice',
    'unitprice',
    'unitprice_tax_excluded',
    'unitprice_tax_included',
    'rrp',
    'replacementprice',
    'rrp_tax_excluded',
    'rrp_tax_included',
    'ecost',
    'ecost_tax_excluded',
    'ecost_tax_included',
    'tax_rate_on_ordering'
);

# create, modify or delete biblio
# create if $quantity>0 and $existing='no'
# modify if $quantity>0 and $existing='yes'
if ( $basket->{is_standing} || $orderinfo->{quantity} ne '0' ) {
    #TODO:check to see if biblio exists
    unless ( $$orderinfo{biblionumber} ) {

        my $record;
        if ( $use_ACQ_framework ) {
            my @tags         = $input->multi_param('bib_tag');
            my @subfields    = $input->multi_param('bib_subfield');
            my @field_values = $input->multi_param('bib_field_value');
            my $xml = TransformHtmlToXml( \@tags, \@subfields, \@field_values );
            $record=MARC::Record::new_from_xml($xml, 'UTF-8');
        } else {
            #if it doesn't create it
            $record = TransformKohaToMarc(
                {
                    "biblio.title"                => "$$orderinfo{title}",
                    "biblio.author"               => $$orderinfo{author}          ? $$orderinfo{author}        : "",
                    "biblio.seriestitle"          => $$orderinfo{series}          ? $$orderinfo{series}        : "",
                    "biblioitems.isbn"            => $$orderinfo{isbn}            ? $$orderinfo{isbn}          : "",
                    "biblioitems.ean"             => $$orderinfo{ean}             ? $$orderinfo{ean}           : "",
                    "biblioitems.publishercode"   => $$orderinfo{publishercode}   ? $$orderinfo{publishercode} : "",
                    "biblioitems.publicationyear" => $$orderinfo{publicationyear} ? $$orderinfo{publicationyear}: "",
                    "biblio.copyrightdate"        => $$orderinfo{publicationyear} ? $$orderinfo{publicationyear}: "",
                    "biblioitems.itemtype"        => $$orderinfo{itemtype} ? $$orderinfo{itemtype} : "",
                    "biblioitems.editionstatement"=> $$orderinfo{editionstatement} ? $$orderinfo{editionstatement} : "",
                });

        }
        C4::Acquisition::FillWithDefaultValues( $record );

        # create the record in catalogue, with framework ''
        my ($biblionumber,$bibitemnum) = AddBiblio($record,'');
        # change suggestion status if applicable
        if ($$orderinfo{suggestionid}) {
            ModSuggestion( {suggestionid=>$$orderinfo{suggestionid}, STATUS=>'ORDERED', biblionumber=>$biblionumber} );
        }
        $orderinfo->{biblionumber}=$biblionumber;
    }

    $orderinfo->{unitprice} = $orderinfo->{ecost} if not defined $orderinfo->{unitprice} or $orderinfo->{unitprice} eq '';

    $orderinfo = C4::Acquisition::populate_order_with_prices(
        {
            order        => $orderinfo,
            booksellerid => $orderinfo->{booksellerid},
            ordering     => 1,
        }
    );

    # if we already have $ordernumber, then it's an ordermodif
    my $order = Koha::Acquisition::Order->new($orderinfo);
    if ( $orderinfo->{ordernumber} ) {
        ModOrder($orderinfo);
        # Log the order modification
        if (C4::Context->preference("AcqLog")) {
            my $infos = '';
            foreach my $field(@log_order_fields) {
                $infos .= sprintf("%010d", $orderinfo->{$field});
            }
            logaction(
                'ACQUISITIONS',
                'MODIFY_ORDER',
                $orderinfo->{ordernumber},
                $infos
            );
        }
    }
    else { # else, it's a new line
        $order->store;
        # Log the order creation
        if (C4::Context->preference("AcqLog")) {
            my $infos = '';
            foreach my $field(@log_order_fields) {
                $infos .= sprintf("%010d", $orderinfo->{$field});
            }
            logaction(
                'ACQUISITIONS',
                'CREATE_ORDER',
                $order->ordernumber,
                $infos
            );
        }
    }
    my $order_users_ids = $input->param('users_ids');
    my @order_users = split( /:/, $order_users_ids );
    ModOrderUsers( $order->ordernumber, @order_users );

    # now, add items if applicable
    if ($basket->effective_create_items eq 'ordering') {

        my @tags         = $input->multi_param('tag');
        my @subfields    = $input->multi_param('subfield');
        my @field_values = $input->multi_param('field_value');
        my @serials      = $input->multi_param('serial');
        my @itemid       = $input->multi_param('itemid');
        my @ind_tag      = $input->multi_param('ind_tag');
        my @indicator    = $input->multi_param('indicator');
        #Rebuilding ALL the data for items into a hash
        # parting them on $itemid.

        my %itemhash;
        my $countdistinct;
        my $range=scalar(@itemid);
        for (my $i=0; $i<$range; $i++){
            unless ($itemhash{$itemid[$i]}){
            $countdistinct++;
            }
        push @{$itemhash{$itemid[$i]}->{'tags'}},$tags[$i];
        push @{$itemhash{$itemid[$i]}->{'subfields'}},$subfields[$i];
            push @{$itemhash{$itemid[$i]}->{'field_values'}},$field_values[$i];
            push @{$itemhash{$itemid[$i]}->{'ind_tag'}},$ind_tag[$i];
            push @{$itemhash{$itemid[$i]}->{'indicator'}},$indicator[$i];
        }
        foreach my $item (keys %itemhash){
            my $xml = TransformHtmlToXml( $itemhash{$item}->{'tags'},
                                    $itemhash{$item}->{'subfields'},
                                    $itemhash{$item}->{'field_values'},
                                    $itemhash{$item}->{'indicator'},
                                    $itemhash{$item}->{'ind_tag'},
                                    'ITEM');
            my $record=MARC::Record::new_from_xml($xml, 'UTF-8');
            my ($barcodefield,$barcodesubfield) = GetMarcFromKohaField('items.barcode');
            next unless ( defined $barcodefield && defined $barcodesubfield );
            my $barcode = $record->subfield($barcodefield,$barcodesubfield) || '';
            my $aBpref = C4::Context->preference('autoBarcode');
            if( $barcode eq '' && $aBpref ne 'OFF'){
                my $barcodeobj;
                if ( $aBpref eq 'hbyymmincr'){
                    my ($homebranchfield,$homebranchsubfield) = GetMarcFromKohaField('items.homebranch');
                    my $homebranch = $record->subfield($homebranchfield,$homebranchsubfield);
                    $barcodeobj = C4::Barcodes->new($aBpref, $homebranch);
                } else {
                    $barcodeobj = C4::Barcodes->new($aBpref);
                }
                $barcode = $barcodeobj->value();
                $record->field($barcodefield)->delete_subfield( code => $barcodesubfield);
                $record->field($barcodefield)->add_subfields($barcodesubfield => $barcode);
            }
            my ($biblionumber,$bibitemnum,$itemnumber) = AddItemFromMarc($record,$$orderinfo{biblionumber});
            $order->add_item($itemnumber);
        }
    }

}

if (C4::Context->preference("AcqLog") && $basketno) {
    logaction(
        'ACQUISITIONS',
        'MODIFY_BASKET',
        $basketno
    );
}

my $booksellerid=$$orderinfo{booksellerid};
if (my $import_batch_id=$$orderinfo{import_batch_id}) {
    print $input->redirect("/cgi-bin/koha/acqui/addorderiso2709.pl?import_batch_id=$import_batch_id&basketno=$basketno&booksellerid=$booksellerid");
} elsif ( defined $orderinfo->{invoiceid} ) {
    print $input->redirect("/cgi-bin/koha/acqui/parcel.pl?invoiceid=" . $orderinfo->{invoiceid});
} else {
    print $input->redirect("/cgi-bin/koha/acqui/basket.pl?basketno=$basketno");
}
