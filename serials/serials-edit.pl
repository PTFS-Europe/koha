#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Parts Copyright 2010 Biblibre
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

serials-edit.pl

=head1 Parameters

=over 4

=item op
op can be :
    * modsubscriptionhistory :to modify the subscription history
    * serialchangestatus     :to modify the status of this subscription

=item subscriptionid

=item user

=item histstartdate

=item enddate

=item recievedlist

=item missinglist

=item opacnote

=item librariannote

=item serialid

=item serialseq

=item planneddate

=item notes

=item status

=back

=cut

use Modern::Perl;
use CGI qw ( -utf8 );
use Encode;
use C4::Auth   qw( get_template_and_user haspermission );
use C4::Biblio qw( GetMarcFromKohaField TransformHtmlToXml );
use C4::Items  qw( AddItemFromMarc ModItemFromMarc PrepareItemrecordDisplay );
use C4::Output qw( output_html_with_http_headers );
use C4::Context;
use C4::Serials
    qw( GetSerials GetSerials2 GetSerialInformation HasSubscriptionExpired GetSubscription abouttoexpire NewIssue ModSerialStatus GetPreviousSerialid AddItem2Serial );
use C4::Search qw( enabled_staff_search_views );

use Koha::DateUtils qw( dt_from_string );
use Koha::Items;
use Koha::Serial::Items;

use List::MoreUtils qw( uniq );
use List::Util      qw( min );

my $query              = CGI->new();
my $dbh                = C4::Context->dbh;
my @serialids          = $query->multi_param('serialid');
my @serialseqs         = $query->multi_param('serialseq');
my @planneddates       = $query->multi_param('planneddate');
my @publisheddates     = $query->multi_param('publisheddate');
my @publisheddatetexts = $query->multi_param('publisheddatetext');
my @status             = $query->multi_param('status');
my @notes              = $query->multi_param('notes');
my @subscriptionids    = $query->multi_param('subscriptionid');
my $op                 = $query->param('op');
my $skip_issues        = $query->param('skip_issues') || 0;

my $count_forward = $skip_issues + 1;

if ( scalar(@subscriptionids) == 1 && index( $subscriptionids[0], q|,| ) > 0 ) {
    @subscriptionids = split( /,/, $subscriptionids[0] );
}
my @errors;
my @errseq;

# If user comes from subscription details
unless (@serialids) {
    my $serstatus = $query->param('serstatus');
    my @statuses  = split ',', $serstatus;
    if ($serstatus) {
        foreach my $subscriptionid (@subscriptionids) {
            my @tmpser = GetSerials2( $subscriptionid, \@statuses );
            push @serialids, map { $_->{serialid} } @tmpser;
        }
    }
}

unless (@serialids) {
    my $string = 'serials-collection.pl?subscriptionid=' . join ',', uniq @subscriptionids;
    $string =~ s/,$//;

    print $query->redirect($string);
    exit;
}

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => 'serials/serials-edit.tt',
        query         => $query,
        type          => 'intranet',
        flagsrequired => { serials => 'receive_serials' },
    }
);

my @serialdatalist;
my %processedserialid;

my $today = dt_from_string;

foreach my $serialid (@serialids) {

    #filtering serialid for duplication
    #NEW serial should appear only once and are created afterwards
    if (   $serialid
        && $serialid =~ /^[0-9]+$/
        && !$processedserialid{$serialid} )
    {
        my $serinfo = GetSerialInformation($serialid);    #TODO duplicates work done by GetSerials2 above

        $serinfo->{arriveddate} = $today;

        $serinfo->{'editdisable'} = ( ( HasSubscriptionExpired( $serinfo->{subscriptionid} ) && $serinfo->{'status1'} )
                || $serinfo->{'cannotedit'} );
        $serinfo->{editdisable} = 0
            if C4::Auth::haspermission( C4::Context->userenv->{id}, { serials => 'receive_serials' } );
        $serinfo->{editdisable} ||= ( $serinfo->{status8} and $serinfo->{closed} );
        push @serialdatalist, $serinfo;
        $processedserialid{$serialid} = 1;
    }
}
my $biblio = Koha::Biblios->find( $serialdatalist[0]->{biblionumber} );

my @newserialloop;
my @subscriptionloop;

# check, for each subscription edited, that we have an empty item line if applicable for the subscription
my %processedsubscriptionid;
foreach my $subscriptionid (@subscriptionids) {

    #Do not process subscriptionid twice if it was already processed.
    if ( $subscriptionid && !$processedsubscriptionid{$subscriptionid} ) {
        my $cell;
        if ( $serialdatalist[0]->{'serialsadditems'} ) {

            #Create New empty item
            $cell = PrepareItemrecordDisplay(
                $serialdatalist[0]->{'biblionumber'},
                '', GetSubscription($subscriptionid)
            );
            $cell->{serialsadditems} = 1;
        }
        $cell->{'subscriptionid'} = $subscriptionid;
        $cell->{biblionumber}     = $serialdatalist[0]->{'biblionumber'};
        $cell->{'itemid'}         = 'NNEW';
        $cell->{'serialid'}       = 'NEW';
        $cell->{'issuesatonce'}   = 1;
        $cell->{arriveddate}      = $today;

        push @newserialloop, $cell;
        push @subscriptionloop,
            {
            'subscriptionid'      => $subscriptionid,
            'abouttoexpire'       => abouttoexpire($subscriptionid),
            'subscriptionexpired' => HasSubscriptionExpired($subscriptionid),
            };
        $processedsubscriptionid{$subscriptionid} = 1;
    }
}
$template->param( newserialloop => \@newserialloop );
$template->param( subscriptions => \@subscriptionloop );

if ( $op and $op eq 'cud-serialchangestatus' ) {

    # Convert serialseqs to UTF-8 to prevent encoding problems
    foreach my $seq (@serialseqs) {
        $seq = Encode::decode( 'UTF-8', $seq ) unless Encode::is_utf8($seq);
    }

    my $newserial;
    for ( my $i = 0 ; $i <= $#serialids ; $i++ ) {
        my ( $plan_date, $pub_date );

        if ( defined $planneddates[$i] && $planneddates[$i] ne 'XXX' ) {
            $plan_date = $planneddates[$i];
        }
        if ( defined $publisheddates[$i] && $publisheddates[$i] ne 'XXX' ) {
            $pub_date = $publisheddates[$i];
        }

        if ( $serialids[$i] && $serialids[$i] eq 'NEW' ) {
            if ( $serialseqs[$i] ) {

                #IF newserial was provided a name Then we have to create a newSerial
                ### FIXME if NewIssue is modified to use subscription biblionumber, then biblionumber would not be useful.
                $newserial = NewIssue(
                    $serialseqs[$i],
                    $subscriptionids[0],
                    $serialdatalist[0]->{'biblionumber'},
                    $status[$i],
                    $plan_date,
                    $pub_date,
                    $publisheddatetexts[$i],
                    $notes[$i],
                    $serialdatalist[0]->{'routingnotes'}
                );
            }
        } elsif ( $serialids[$i] ) {
            ModSerialStatus(
                $serialids[$i],
                $serialseqs[$i],
                $plan_date,
                $pub_date,
                $publisheddatetexts[$i],
                $status[$i],
                $notes[$i],
                $count_forward
            );
        }
        my $makePreviousSerialAvailable = C4::Context->preference('makePreviousSerialAvailable');
        if ( $makePreviousSerialAvailable && $serialids[$i] ne "NEW" ) {

            # We already have created the new expected serial at this point, so we get the second previous serial
            my $previous = GetPreviousSerialid( $subscriptionids[$i] );
            if ($previous) {

                my $serialitem = Koha::Serial::Items->search( { serialid => $previous } )->next;
                my $itemnumber = $serialitem ? $serialitem->itemnumber : undef;
                if ($itemnumber) {

                    # Getting the itemtype to set from the database
                    my $subscriptioninfos = GetSubscription( $subscriptionids[$i] );

                    # Changing the status to "available" and the itemtype according to the previousitemtype db field
                    my $item = Koha::Items->find($itemnumber);
                    $item->set(
                        {
                            notforloan => 0,
                            itype      => $subscriptioninfos->{'previousitemtype'}
                        }
                    )->store;
                }
            }
        }

    }
    my @moditems = $query->multi_param('moditem');
    if ( scalar(@moditems) ) {
        my @tags         = $query->multi_param('tag');
        my @subfields    = $query->multi_param('subfield');
        my @field_values = $query->multi_param('field_value');
        my @serials      = $query->multi_param('serial');
        my @bibnums      = $query->multi_param('bibnum');
        my @itemid       = $query->multi_param('itemid');
        my @num_copies   = map { min( $_, 1000 ); } $query->multi_param('number_of_copies');

        #Rebuilding ALL the data for items into a hash
        # parting them on $itemid.
        my %itemhash;
        my $countdistinct = 0;
        my $range         = scalar(@itemid);
        for ( my $i = 0 ; $i < $range ; $i++ ) {
            unless ( $itemhash{ $itemid[$i] } ) {
                if (   $serials[$countdistinct]
                    && $serials[$countdistinct] ne "NEW" )
                {
                    $itemhash{ $itemid[$i] }->{'serial'} =
                        $serials[$countdistinct];
                } else {
                    $itemhash{ $itemid[$i] }->{'serial'} = $newserial;
                }
                $itemhash{ $itemid[$i] }->{'bibnum'}     = $bibnums[$countdistinct];
                $itemhash{ $itemid[$i] }->{'num_copies'} = $num_copies[$countdistinct];
                $countdistinct++;
            }
            push @{ $itemhash{ $itemid[$i] }->{'tags'} },      $tags[$i];
            push @{ $itemhash{ $itemid[$i] }->{'subfields'} }, $subfields[$i];
            push @{ $itemhash{ $itemid[$i] }->{'field_values'} },
                $field_values[$i];
        }
        foreach my $item ( keys %itemhash ) {

            # Verify Itemization is "Valid", i.e. serial status is Arrived or Missing
            my $index = -1;
            for ( my $i = 0 ; $i < scalar(@serialids) ; $i++ ) {
                if (
                    $itemhash{$item}->{serial} eq $serialids[$i]
                    || (   $itemhash{$item}->{serial} == $newserial
                        && $serialids[$i] eq 'NEW' )
                    )
                {
                    $index = $i;
                }
            }
            if ( $index >= 0 && $status[$index] == 2 ) {
                my $xml = TransformHtmlToXml(
                    $itemhash{$item}->{'tags'},
                    $itemhash{$item}->{'subfields'},
                    $itemhash{$item}->{'field_values'},
                    undef,
                    undef
                );

                # warn $xml;
                my $bib_record = MARC::Record::new_from_xml( $xml, 'UTF-8' );
                if ( $item =~ /^N/ ) {

                    $itemhash{$item}->{'num_copies'} //= 1;

                    for ( my $copy = 0 ; $copy < $itemhash{$item}->{'num_copies'} ; ) {

                        # New Item

                        # if autoBarcode is set to 'incremental', calculate barcode...
                        my ( $barcodetagfield, $barcodetagsubfield ) = GetMarcFromKohaField('items.barcode');
                        if ( C4::Context->preference('autoBarcode') eq 'incremental' ) {
                            if (
                                !(
                                       $bib_record->field($barcodetagfield)
                                    && $bib_record->field($barcodetagfield)->subfield($barcodetagsubfield)
                                )
                                )
                            {
                                my $sth_barcode = $dbh->prepare('select max(abs(barcode)) from items');
                                $sth_barcode->execute;
                                my ($newbarcode) = $sth_barcode->fetchrow;

                                # OK, we have the new barcode, add the entry in MARC record # FIXME -> should be  using barcode plugin here.
                                $bib_record->field($barcodetagfield)->update( $barcodetagsubfield => ++$newbarcode );
                            }
                        }

                        # check for item barcode # being unique
                        my $exists;
                        if ( $bib_record->subfield( $barcodetagfield, $barcodetagsubfield ) ) {
                            my $barcode = $bib_record->subfield( $barcodetagfield, $barcodetagsubfield );

                            if ( $copy > 0 ) {
                                use C4::Barcodes;
                                my $barcodeobj = C4::Barcodes->new;
                                my $newbarcode = $barcodeobj->next_value($barcode);
                                $barcode = $newbarcode;
                                $bib_record->field($barcodetagfield)->update( $barcodetagsubfield => $barcode );
                            }

                            $exists = Koha::Items->find( { barcode => $barcode } );
                        }

                        #           push @errors,"barcode_not_unique" if($exists);
                        # if barcode exists, don't create, but report The problem.
                        if ($exists) {
                            push @errors, 'barcode_not_unique';
                            push @errseq, { serialseq => $serialseqs[$index] };
                        } else {
                            my ( $biblionumber, $bibitemnum, $itemnumber ) = AddItemFromMarc(
                                $bib_record,
                                $itemhash{$item}->{bibnum}
                            );
                            AddItem2Serial(
                                $itemhash{$item}->{serial},
                                $itemnumber
                            );
                        }
                        $copy++;
                    }

                }    # if ( $item =~ /^N/ ) {

                else {

                    #modify item
                    my ( $oldbiblionumber, $oldbibnum, $itemnumber ) = ModItemFromMarc(
                        $bib_record,
                        $itemhash{$item}->{'bibnum'}, $item
                    );
                }
            }
        }
    }

    if (@errors) {
        $template->param( Errors => 1 );
        if (@errseq) {
            $template->param( barcode_not_unique => 1, errseq => \@errseq );
        }
    } else {
        my $redirect = 'serials-collection.pl?';
        $redirect .= join( '&', map { 'subscriptionid=' . $_ } @subscriptionids );
        print $query->redirect($redirect);
    }
}
my $location = $serialdatalist[0]->{'location'};

$template->param(
    subscriptionid                                   => $serialdatalist[0]->{subscriptionid},
    serialsadditems                                  => $serialdatalist[0]->{'serialsadditems'},
    callnumber                                       => $serialdatalist[0]->{'callnumber'},
    internalnotes                                    => $serialdatalist[0]->{'internalnotes'},
    bibliotitle                                      => $biblio->title,
    biblionumber                                     => $serialdatalist[0]->{'biblionumber'},
    serialslist                                      => \@serialdatalist,
    location                                         => $location,
    ( uc( C4::Context->preference("marcflavour") ) ) => 1

);
output_html_with_http_headers $query, $cookie, $template->output;
