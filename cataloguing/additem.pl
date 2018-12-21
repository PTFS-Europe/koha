#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2004-2010 BibLibre
# Parts Copyright Catalyst IT 2011
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

use Modern::Perl;

use CGI qw ( -utf8 );
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Context;
use C4::Circulation;
use C4::Koha;
use C4::ClassSource;
use Koha::DateUtils;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Libraries;
use Koha::Patrons;
use List::MoreUtils qw/any/;
use C4::Search;
use Storable qw(thaw freeze);
use URI::Escape;
use C4::Members;

use MARC::File::XML;
use URI::Escape;

our $dbh = C4::Context->dbh;

sub find_value {
    my ($tagfield,$insubfield,$record) = @_;
    my $result;
    my $indicator;
    foreach my $field ($record->field($tagfield)) {
        my @subfields = $field->subfields();
        foreach my $subfield (@subfields) {
            if (@$subfield[0] eq $insubfield) {
                $result .= @$subfield[1];
                $indicator = $field->indicator(1).$field->indicator(2);
            }
        }
    }
    return($indicator,$result);
}

sub get_item_from_barcode {
    my ($barcode)=@_;
    my $dbh=C4::Context->dbh;
    my $result;
    my $rq=$dbh->prepare("SELECT itemnumber from items where items.barcode=?");
    $rq->execute($barcode);
    ($result)=$rq->fetchrow;
    return($result);
}

sub set_item_default_location {
    my $itemnumber = shift;
    my $item = GetItem( $itemnumber );
    if ( C4::Context->preference('NewItemsDefaultLocation') ) {
        $item->{'permanent_location'} = $item->{'location'};
        $item->{'location'} = C4::Context->preference('NewItemsDefaultLocation');
        ModItem( $item, undef, $itemnumber);
    }
    else {
      $item->{'permanent_location'} = $item->{'location'} if !defined($item->{'permanent_location'});
      ModItem( $item, undef, $itemnumber);
    }
}

# NOTE: This code is subject to change in the future with the implemenation of ajax based autobarcode code
# NOTE: 'incremental' is the ONLY autoBarcode option available to those not using javascript
sub _increment_barcode {
    my ($record, $frameworkcode) = @_;
    my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);
    unless ($record->field($tagfield)->subfield($tagsubfield)) {
        my $sth_barcode = $dbh->prepare("select max(abs(barcode)) from items");
        $sth_barcode->execute;
        my ($newbarcode) = $sth_barcode->fetchrow;
        $newbarcode++;
        # OK, we have the new barcode, now create the entry in MARC record
        my $fieldItem = $record->field($tagfield);
        $record->delete_field($fieldItem);
        $fieldItem->add_subfields($tagsubfield => $newbarcode);
        $record->insert_fields_ordered($fieldItem);
    }
    return $record;
}


sub generate_subfield_form {
        my ($tag, $subfieldtag, $value, $tagslib,$subfieldlib, $branches, $biblionumber, $temp, $loop_data, $i, $restrictededition) = @_;
  
        my $frameworkcode = &GetFrameworkCode($biblionumber);

        my %subfield_data;
        my $dbh = C4::Context->dbh;
        
        my $index_subfield = int(rand(1000000)); 
        if ($subfieldtag eq '@'){
            $subfield_data{id} = "tag_".$tag."_subfield_00_".$index_subfield;
        } else {
            $subfield_data{id} = "tag_".$tag."_subfield_".$subfieldtag."_".$index_subfield;
        }
        
        $subfield_data{tag}        = $tag;
        $subfield_data{subfield}   = $subfieldtag;
        $subfield_data{marc_lib}   ="<span id=\"error$i\" title=\"".$subfieldlib->{lib}."\">".$subfieldlib->{lib}."</span>";
        $subfield_data{mandatory}  = $subfieldlib->{mandatory};
        $subfield_data{repeatable} = $subfieldlib->{repeatable};
        $subfield_data{maxlength}  = $subfieldlib->{maxlength};
        
        if ( ! defined( $value ) || $value eq '')  {
            $value = $subfieldlib->{defaultvalue};
            if ( $value ) {
                # get today date & replace <<YYYY>>, <<MM>>, <<DD>> if provided in the default value
                my $today_dt = dt_from_string;
                my $year = $today_dt->strftime('%Y');
                my $month = $today_dt->strftime('%m');
                my $day = $today_dt->strftime('%d');
                $value =~ s/<<YYYY>>/$year/g;
                $value =~ s/<<MM>>/$month/g;
                $value =~ s/<<DD>>/$day/g;
                # And <<USER>> with surname (?)
                my $username=(C4::Context->userenv?C4::Context->userenv->{'surname'}:"superlibrarian");
                $value=~s/<<USER>>/$username/g;
            }
        }

        $subfield_data{visibility} = "display:none;" if (($subfieldlib->{hidden} > 4) || ($subfieldlib->{hidden} <= -4));

        my $pref_itemcallnumber = C4::Context->preference('itemcallnumber');
        if (!$value && $subfieldlib->{kohafield} eq 'items.itemcallnumber' && $pref_itemcallnumber) {
            my $CNtag       = substr($pref_itemcallnumber, 0, 3);
            my $CNsubfield  = substr($pref_itemcallnumber, 3, 1);
            my $CNsubfield2 = substr($pref_itemcallnumber, 4, 1);
            my $temp2 = $temp->field($CNtag);
            if ($temp2) {
                $value = join ' ', $temp2->subfield($CNsubfield) || q{}, $temp2->subfield($CNsubfield2) || q{};
                #remove any trailing space incase one subfield is used
                $value =~ s/^\s+|\s+$//g;
            }
        }
        
        if ($frameworkcode eq 'FA' && $subfieldlib->{kohafield} eq 'items.barcode' && !$value){
	    my $input = new CGI;
	    $value = $input->param('barcode');
	}

        if ( $subfieldlib->{authorised_value} ) {
            my @authorised_values;
            my %authorised_lib;
            # builds list, depending on authorised value...
            if ( $subfieldlib->{authorised_value} eq "branches" ) {
                foreach my $thisbranch (@$branches) {
                    push @authorised_values, $thisbranch->{branchcode};
                    $authorised_lib{$thisbranch->{branchcode}} = $thisbranch->{branchname};
                    $value = $thisbranch->{branchcode} if $thisbranch->{selected} && !$value;
                }
            }
            elsif ( $subfieldlib->{authorised_value} eq "itemtypes" ) {
                  push @authorised_values, "";
                  my $itemtypes = Koha::ItemTypes->search_with_localization;
                  while ( my $itemtype = $itemtypes->next ) {
                      push @authorised_values, $itemtype->itemtype;
                      $authorised_lib{$itemtype->itemtype} = $itemtype->translated_description;
                  }

                  unless ( $value ) {
                      my $itype_sth = $dbh->prepare("SELECT itemtype FROM biblioitems WHERE biblionumber = ?");
                      $itype_sth->execute( $biblionumber );
                      ( $value ) = $itype_sth->fetchrow_array;
                  }
          
                  #---- class_sources
            }
            elsif ( $subfieldlib->{authorised_value} eq "cn_source" ) {
                  push @authorised_values, "";
                    
                  my $class_sources = GetClassSources();
                  my $default_source = C4::Context->preference("DefaultClassificationSource");
                  
                  foreach my $class_source (sort keys %$class_sources) {
                      next unless $class_sources->{$class_source}->{'used'} or
                                  ($value and $class_source eq $value)      or
                                  ($class_source eq $default_source);
                      push @authorised_values, $class_source;
                      $authorised_lib{$class_source} = $class_sources->{$class_source}->{'description'};
                  }
        		  $value = $default_source unless ($value);
        
                  #---- "true" authorised value
            }
            else {
                  push @authorised_values, qq{};
                  my $av = GetAuthorisedValues( $subfieldlib->{authorised_value} );
                  for my $r ( @$av ) {
                      push @authorised_values, $r->{authorised_value};
                      $authorised_lib{$r->{authorised_value}} = $r->{lib};
                  }
            }

            if ( $subfieldlib->{hidden} > 4 or $subfieldlib->{hidden} <= -4 ) {
                $subfield_data{marc_value} = {
                    type        => 'hidden',
                    id          => $subfield_data{id},
                    maxlength   => $subfield_data{maxlength},
                    value       => $value,
                };
            }
            else {
                $subfield_data{marc_value} = {
                    type     => 'select',
                    id       => "tag_".$tag."_subfield_".$subfieldtag."_".$index_subfield,
                    values   => \@authorised_values,
                    labels   => \%authorised_lib,
                    default  => $value,
                };
            }
        }
            # it's a thesaurus / authority field
        elsif ( $subfieldlib->{authtypecode} ) {
                $subfield_data{marc_value} = {
                    type         => 'text_auth',
                    id           => $subfield_data{id},
                    maxlength    => $subfield_data{maxlength},
                    value        => $value,
                    authtypecode => $subfieldlib->{authtypecode},
                };
        }
            # it's a plugin field
        elsif ( $subfieldlib->{value_builder} ) { # plugin
            require Koha::FrameworkPlugin;
            my $plugin = Koha::FrameworkPlugin->new({
                name => $subfieldlib->{'value_builder'},
                item_style => 1,
            });
            my $pars=  { dbh => $dbh, record => $temp, tagslib =>$tagslib,
                id => $subfield_data{id}, tabloop => $loop_data };
            $plugin->build( $pars );
            if( !$plugin->errstr ) {
                my $class= 'buttonDot'. ( $plugin->noclick? ' disabled': '' );
                $subfield_data{marc_value} = {
                    type        => 'text_plugin',
                    id          => $subfield_data{id},
                    maxlength   => $subfield_data{maxlength},
                    value       => $value,
                    class       => $class,
                    nopopup     => $plugin->noclick,
                    javascript  => $plugin->javascript,
                };
            } else {
                warn $plugin->errstr;
                $subfield_data{marc_value} = {
                    type        => 'text',
                    id          => $subfield_data{id},
                    maxlength   => $subfield_data{maxlength},
                    value       => $value,
                }; # supply default input form
            }
        }
        elsif ( $tag eq '' ) {       # it's an hidden field
            $subfield_data{marc_value} = {
                type        => 'hidden',
                id          => $subfield_data{id},
                maxlength   => $subfield_data{maxlength},
                value       => $value,
            };
        }
        elsif ( $subfieldlib->{'hidden'} ) {   # FIXME: shouldn't input type be "hidden" ?
            $subfield_data{marc_value} = {
                type        => 'text',
                id          => $subfield_data{id},
                maxlength   => $subfield_data{maxlength},
                value       => $value,
            };
        }
        elsif (
                (
                    $value and length($value) > 100
                )
                or (
                    C4::Context->preference("marcflavour") eq "UNIMARC"
                    and 300 <= $tag && $tag < 400 && $subfieldtag eq 'a'
                )
                or (
                    C4::Context->preference("marcflavour") eq "MARC21"
                    and 500 <= $tag && $tag < 600
                )
              ) {
            # oversize field (textarea)
            $subfield_data{marc_value} = {
                type        => 'textarea',
                id          => $subfield_data{id},
                value       => $value,
            };
        } else {
            # it's a standard field
            $subfield_data{marc_value} = {
                type        => 'text',
                id          => $subfield_data{id},
                maxlength   => $subfield_data{maxlength},
                value       => $value,
            };
        }

        # Getting list of subfields to keep when restricted editing is enabled
        my $subfieldsToAllowForRestrictedEditing = C4::Context->preference('SubfieldsToAllowForRestrictedEditing');
        my $allowAllSubfields = (
            not defined $subfieldsToAllowForRestrictedEditing
              or $subfieldsToAllowForRestrictedEditing eq q||
        ) ? 1 : 0;
        my @subfieldsToAllow = split(/ /, $subfieldsToAllowForRestrictedEditing);

        # If we're on restricted editing, and our field is not in the list of subfields to allow,
        # then it is read-only
        $subfield_data{marc_value}->{readonly} = (
            not $allowAllSubfields
            and $restrictededition
            and !grep { $tag . '$' . $subfieldtag  eq $_ } @subfieldsToAllow
        ) ? 1: 0;

        return \%subfield_data;
}

# Removes some subfields when prefilling items
# This function will remove any subfield that is not in the SubfieldsToUseWhenPrefill syspref
sub removeFieldsForPrefill {

    my $item = shift;

    # Getting item tag
    my ($tag, $subtag) = GetMarcFromKohaField("items.barcode", '');

    # Getting list of subfields to keep
    my $subfieldsToUseWhenPrefill = C4::Context->preference('SubfieldsToUseWhenPrefill');

    # Removing subfields that are not in the syspref
    if ($tag && $subfieldsToUseWhenPrefill) {
        my $field = $item->field($tag);
        my @subfieldsToUse= split(/ /,$subfieldsToUseWhenPrefill);
        foreach my $subfield ($field->subfields()) {
            if (!grep { $subfield->[0] eq $_ } @subfieldsToUse) {
                $field->delete_subfield(code => $subfield->[0]);
            }

        }
    }

    return $item;

}

my $input        = new CGI;
my $error        = $input->param('error');
my $biblionumber = $input->param('biblionumber');
my $itemnumber   = $input->param('itemnumber');
my $op           = $input->param('op') || q{};
my $hostitemnumber = $input->param('hostitemnumber');
my $marcflavour  = C4::Context->preference("marcflavour");
my $searchid     = $input->param('searchid');
# fast cataloguing datas
my $fa_circborrowernumber = $input->param('circborrowernumber');
my $fa_barcode            = $input->param('barcode');
my $fa_branch             = $input->param('branch');
my $fa_stickyduedate      = $input->param('stickyduedate');
my $fa_duedatespec        = $input->param('duedatespec');

my $frameworkcode = &GetFrameworkCode($biblionumber);

# Defining which userflag is needing according to the framework currently used
my $userflags;
if (defined $input->param('frameworkcode')) {
    $userflags = ($input->param('frameworkcode') eq 'FA') ? "fast_cataloging" : "edit_items";
}

if (not defined $userflags) {
    $userflags = ($frameworkcode eq 'FA') ? "fast_cataloging" : "edit_items";
}

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "cataloguing/additem.tt",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {editcatalogue => $userflags},
                 debug => 1,
                 });


# Does the user have a restricted item editing permission?
my $uid = Koha::Patrons->find( $loggedinuser )->userid;
my $restrictededition = $uid ? haspermission($uid,  {'editcatalogue' => 'edit_items_restricted'}) : undef;
# In case user is a superlibrarian, editing is not restricted
$restrictededition = 0 if ($restrictededition != 0 &&  C4::Context->IsSuperLibrarian());
# In case user has fast cataloging permission (and we're in fast cataloging), editing is not restricted
$restrictededition = 0 if ($restrictededition != 0 && $frameworkcode eq 'FA' && haspermission($uid, {'editcatalogue' => 'fast_cataloging'}));

my $tagslib = &GetMarcStructure(1,$frameworkcode);
my $record = GetMarcBiblio({ biblionumber => $biblionumber });
my $oldrecord = TransformMarcToKoha($record);
my $itemrecord;
my $nextop="additem";
my @errors; # store errors found while checking data BEFORE saving item.

# Getting last created item cookie
my $prefillitem = C4::Context->preference('PrefillItem');
my $justaddeditem;
my $cookieitemrecord;
if ($prefillitem) {
    my $lastitemcookie = $input->cookie('LastCreatedItem');
    if ($lastitemcookie) {
        $lastitemcookie = uri_unescape($lastitemcookie);
        eval {
            if ( thaw($lastitemcookie) ) {
                $cookieitemrecord = thaw($lastitemcookie);
                $cookieitemrecord = removeFieldsForPrefill($cookieitemrecord);
            }
        };
        if ($@) {
            $lastitemcookie = 'undef' unless $lastitemcookie;
            warn "Storable::thaw failed to thaw LastCreatedItem-cookie. Cookie value '$lastitemcookie'. Caught error follows: '$@'";
        }
    }
}

#-------------------------------------------------------------------------------
if ($op eq "additem") {

    #-------------------------------------------------------------------------------
    # rebuild
    my @tags      = $input->multi_param('tag');
    my @subfields = $input->multi_param('subfield');
    my @values    = $input->multi_param('field_value');
    # build indicator hash.
    my @ind_tag   = $input->multi_param('ind_tag');
    my @indicator = $input->multi_param('indicator');
    my $xml = TransformHtmlToXml(\@tags,\@subfields,\@values,\@indicator,\@ind_tag, 'ITEM');
    my $record = MARC::Record::new_from_xml($xml, 'UTF-8');

    # type of add
    my $add_submit                 = $input->param('add_submit');
    my $add_duplicate_submit       = $input->param('add_duplicate_submit');
    my $add_multiple_copies_submit = $input->param('add_multiple_copies_submit');
    my $number_of_copies           = $input->param('number_of_copies');

    # This is a bit tricky : if there is a cookie for the last created item and
    # we just added an item, the cookie value is not correct yet (it will be updated
    # next page). To prevent the form from being filled with outdated values, we
    # force the use of "add and duplicate" feature, so the form will be filled with
    # correct values.
    $add_duplicate_submit = 1 if ($prefillitem);
    $justaddeditem = 1;

    # if autoBarcode is set to 'incremental', calculate barcode...
    if ( C4::Context->preference('autoBarcode') eq 'incremental' ) {
        $record = _increment_barcode($record, $frameworkcode);
    }

    my $addedolditem = TransformMarcToKoha( $record );

    # If we have to add or add & duplicate, we add the item
    if ( $add_submit || $add_duplicate_submit ) {

        # check for item barcode # being unique
        my $exist_itemnumber = get_item_from_barcode( $addedolditem->{'barcode'} );
        push @errors, "barcode_not_unique" if ($exist_itemnumber);

        # if barcode exists, don't create, but report The problem.
        unless ($exist_itemnumber) {
            my ( $oldbiblionumber, $oldbibnum, $oldbibitemnum ) = AddItemFromMarc( $record, $biblionumber );
            set_item_default_location($oldbibitemnum);

            # Pushing the last created item cookie back
            if ($prefillitem && defined $record) {
                my $itemcookie = $input->cookie(
                    -name => 'LastCreatedItem',
                    # We uri_escape the whole freezed structure so we're sure we won't have any encoding problems
                    -value   => uri_escape_utf8( freeze( $record ) ),
                    -HttpOnly => 1,
                    -expires => ''
                );

                $cookie = [ $cookie, $itemcookie ];
            }

        }
        $nextop = "additem";
        if ($exist_itemnumber) {
            $itemrecord = $record;
        }
    }

    # If we have to add & duplicate
    if ($add_duplicate_submit) {
        $itemrecord = $record;
        if (C4::Context->preference('autoBarcode') eq 'incremental') {
            $itemrecord = _increment_barcode($itemrecord, $frameworkcode);
        }
        else {
            # we have to clear the barcode field in the duplicate item record to make way for the new one generated by the javascript plugin
            my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);
            my $fieldItem = $itemrecord->field($tagfield);
            $itemrecord->delete_field($fieldItem);
            $fieldItem->delete_subfields($tagsubfield);
            $itemrecord->insert_fields_ordered($fieldItem);
        }
    $itemrecord = removeFieldsForPrefill($itemrecord) if ($prefillitem);
    }

    # If we have to add multiple copies
    if ($add_multiple_copies_submit) {

        use C4::Barcodes;
        my $barcodeobj = C4::Barcodes->new;
        my $oldbarcode = $addedolditem->{'barcode'};
        my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);

    # If there is a barcode and we can't find their new values, we can't add multiple copies
	my $testbarcode;
        $testbarcode = $barcodeobj->next_value($oldbarcode) if $barcodeobj;
	if ($oldbarcode && !$testbarcode) {

	    push @errors, "no_next_barcode";
	    $itemrecord = $record;

	} else {
	# We add each item

	    # For the first iteration
	    my $barcodevalue = $oldbarcode;
	    my $exist_itemnumber;


	    for (my $i = 0; $i < $number_of_copies;) {

		# If there is a barcode
		if ($barcodevalue) {

		    # Getting a new barcode (if it is not the first iteration or the barcode we tried already exists)
		    $barcodevalue = $barcodeobj->next_value($oldbarcode) if ($i > 0 || $exist_itemnumber);

		    # Putting it into the record
		    if ($barcodevalue) {
			$record->field($tagfield)->update($tagsubfield => $barcodevalue);
		    }

		    # Checking if the barcode already exists
		    $exist_itemnumber = get_item_from_barcode($barcodevalue);
		}

		# Adding the item
        if (!$exist_itemnumber) {
            my ($oldbiblionumber,$oldbibnum,$oldbibitemnum) = AddItemFromMarc($record,$biblionumber);
            set_item_default_location($oldbibitemnum);

            # We count the item only if it was really added
            # That way, all items are added, even if there was some already existing barcodes
            # FIXME : Please note that there is a risk of infinite loop here if we never find a suitable barcode
            $i++;
        }

		# Preparing the next iteration
		$oldbarcode = $barcodevalue;
	    }
	    undef($itemrecord);
	}
    }	
    if ($frameworkcode eq 'FA' && $fa_circborrowernumber){
        print $input->redirect(
           '/cgi-bin/koha/circ/circulation.pl?'
           .'borrowernumber='.$fa_circborrowernumber
           .'&barcode='.uri_escape_utf8($fa_barcode)
           .'&duedatespec='.$fa_duedatespec
           .'&stickyduedate=1'
        );
        exit;
    }


#-------------------------------------------------------------------------------
} elsif ($op eq "edititem") {
#-------------------------------------------------------------------------------
# retrieve item if exist => then, it's a modif
    $itemrecord = C4::Items::GetMarcItem($biblionumber,$itemnumber);
    $nextop = "saveitem";
#-------------------------------------------------------------------------------
} elsif ($op eq "dupeitem") {
#-------------------------------------------------------------------------------
# retrieve item if exist => then, it's a modif
    $itemrecord = C4::Items::GetMarcItem($biblionumber,$itemnumber);
    if (C4::Context->preference('autoBarcode') eq 'incremental') {
        $itemrecord = _increment_barcode($itemrecord, $frameworkcode);
    }
    else {
        # we have to clear the barcode field in the duplicate item record to make way for the new one generated by the javascript plugin
        my ($tagfield,$tagsubfield) = &GetMarcFromKohaField("items.barcode",$frameworkcode);
        my $fieldItem = $itemrecord->field($tagfield);
        $itemrecord->delete_field($fieldItem);
        $fieldItem->delete_subfields($tagsubfield);
        $itemrecord->insert_fields_ordered($fieldItem);
    }

    #check for hidden subfield and remove them for the duplicated item
    foreach my $field ($itemrecord->fields()){
        my $tag = $field->{_tag};
        foreach my $subfield ($field->subfields()){
            my $subfieldtag = $subfield->[0];
            if ($tagslib->{$tag}->{$subfieldtag}->{'tab'} ne "10"
            ||  abs($tagslib->{$tag}->{$subfieldtag}->{hidden})>4 ){
                my $fieldItem = $itemrecord->field($tag);
                $itemrecord->delete_field($fieldItem);
                $fieldItem->delete_subfields($subfieldtag);
                $itemrecord->insert_fields_ordered($fieldItem);
            }
        }
    }

    $itemrecord = removeFieldsForPrefill($itemrecord) if ($prefillitem);
    $nextop = "additem";
#-------------------------------------------------------------------------------
} elsif ($op eq "delitem") {
#-------------------------------------------------------------------------------
    # check that there is no issue on this item before deletion.
    $error = &DelItemCheck( $biblionumber,$itemnumber);
    if($error == 1){
        print $input->redirect("additem.pl?biblionumber=$biblionumber&frameworkcode=$frameworkcode&searchid=$searchid");
    }else{
        push @errors,$error;
        $nextop="additem";
    }
#-------------------------------------------------------------------------------
} elsif ($op eq "delallitems") {
#-------------------------------------------------------------------------------
    my @itemnumbers = Koha::Items->search({ biblionumber => $biblionumber })->get_column('itemnumber');
    foreach my $itemnumber ( @itemnumbers ) {
        $error = C4::Items::DelItemCheck( $biblionumber, $itemnumber );
        next if $error == 1; # Means ok
        push @errors,$error;
    }
    if ( @errors ) {
        $nextop="additem";
    } else {
        my $defaultview = C4::Context->preference('IntranetBiblioDefaultView');
        my $views = { C4::Search::enabled_staff_search_views };
        if ($defaultview eq 'isbd' && $views->{can_view_ISBD}) {
            print $input->redirect("/cgi-bin/koha/catalogue/ISBDdetail.pl?biblionumber=$biblionumber&searchid=$searchid");
        } elsif  ($defaultview eq 'marc' && $views->{can_view_MARC}) {
            print $input->redirect("/cgi-bin/koha/catalogue/MARCdetail.pl?biblionumber=$biblionumber&searchid=$searchid");
        } elsif  ($defaultview eq 'labeled_marc' && $views->{can_view_labeledMARC}) {
            print $input->redirect("/cgi-bin/koha/catalogue/labeledMARCdetail.pl?biblionumber=$biblionumber&searchid=$searchid");
        } else {
            print $input->redirect("/cgi-bin/koha/catalogue/detail.pl?biblionumber=$biblionumber&searchid=$searchid");
        }
        exit;
    }
#-------------------------------------------------------------------------------
} elsif ($op eq "saveitem") {
#-------------------------------------------------------------------------------
    # rebuild
    my @tags      = $input->multi_param('tag');
    my @subfields = $input->multi_param('subfield');
    my @values    = $input->multi_param('field_value');
    # build indicator hash.
    my @ind_tag   = $input->multi_param('ind_tag');
    my @indicator = $input->multi_param('indicator');
    # my $itemnumber = $input->param('itemnumber');
    my $xml = TransformHtmlToXml(\@tags,\@subfields,\@values,\@indicator,\@ind_tag,'ITEM');
    my $itemtosave=MARC::Record::new_from_xml($xml, 'UTF-8');
    # MARC::Record builded => now, record in DB
    # warn "R: ".$record->as_formatted;
    # check that the barcode don't exist already
    my $addedolditem = TransformMarcToKoha($itemtosave);
    my $exist_itemnumber = get_item_from_barcode($addedolditem->{'barcode'});
    if ($exist_itemnumber && $exist_itemnumber != $itemnumber) {
        push @errors,"barcode_not_unique";
    } else {
        my $item = GetItem( $itemnumber );
        my $newitem = ModItemFromMarc($itemtosave, $biblionumber, $itemnumber);
        $itemnumber = q{};
        my $olditemlost = $item->{itemlost};
        my $newitemlost = $newitem->{itemlost};
        LostItem( $item->{itemnumber}, 'additem' )
            if $newitemlost && $newitemlost ge '1' && !$olditemlost;
    }
    $nextop="additem";
} elsif ($op eq "delinkitem"){
    my $analyticfield = '773';
	if ($marcflavour  eq 'MARC21' || $marcflavour eq 'NORMARC'){
        $analyticfield = '773';
    } elsif ($marcflavour eq 'UNIMARC') {
        $analyticfield = '461';
    }
    foreach my $field ($record->field($analyticfield)){
        if ($field->subfield('9') eq $hostitemnumber){
            $record->delete_field($field);
            last;
        }
    }
	my $modbibresult = ModBiblio($record, $biblionumber,'');
}

#
#-------------------------------------------------------------------------------
# build screen with existing items. and "new" one
#-------------------------------------------------------------------------------

# now, build existiing item list
my $temp = GetMarcBiblio({ biblionumber => $biblionumber });
#my @fields = $record->fields();


my %witness; #---- stores the list of subfields used at least once, with the "meaning" of the code
my @big_array;
#---- finds where items.itemnumber is stored
my (  $itemtagfield,   $itemtagsubfield) = &GetMarcFromKohaField("items.itemnumber", $frameworkcode);
my ($branchtagfield, $branchtagsubfield) = &GetMarcFromKohaField("items.homebranch", $frameworkcode);
C4::Biblio::EmbedItemsInMarcBiblio({
    marc_record  => $temp,
    biblionumber => $biblionumber });
my @fields = $temp->fields();


my @hostitemnumbers;
if ( C4::Context->preference('EasyAnalyticalRecords') ) {
    my $analyticfield = '773';
    if ($marcflavour  eq 'MARC21' || $marcflavour eq 'NORMARC') {
        $analyticfield = '773';
    } elsif ($marcflavour eq 'UNIMARC') {
        $analyticfield = '461';
    }
    foreach my $hostfield ($temp->field($analyticfield)){
        my $hostbiblionumber = $hostfield->subfield('0');
        if ($hostbiblionumber){
            my $hostrecord = GetMarcBiblio({
                biblionumber => $hostbiblionumber,
                embed_items  => 1 });
            if ($hostrecord) {
                my ($itemfield, undef) = GetMarcFromKohaField( 'items.itemnumber', GetFrameworkCode($hostbiblionumber) );
                foreach my $hostitem ($hostrecord->field($itemfield)){
                    if ($hostitem->subfield('9') eq $hostfield->subfield('9')){
                        push (@fields, $hostitem);
                        push (@hostitemnumbers, $hostfield->subfield('9'));
                    }
                }
            }
        }
    }
}


foreach my $field (@fields) {
    next if ( $field->tag() < 10 );

    my @subf = $field->subfields or ();    # don't use ||, as that forces $field->subfelds to be interpreted in scalar context
    my %this_row;
    # loop through each subfield
    my $i = 0;
    foreach my $subfield (@subf){
        my $subfieldcode = $subfield->[0];
        my $subfieldvalue= $subfield->[1];

        next if ($tagslib->{$field->tag()}->{$subfieldcode}->{tab} ne 10 
                && ($field->tag() ne $itemtagfield 
                && $subfieldcode   ne $itemtagsubfield));
        $witness{$subfieldcode} = $tagslib->{$field->tag()}->{$subfieldcode}->{lib} if ($tagslib->{$field->tag()}->{$subfieldcode}->{tab}  eq 10);
		if ($tagslib->{$field->tag()}->{$subfieldcode}->{tab}  eq 10) {
		    $this_row{$subfieldcode} .= " | " if($this_row{$subfieldcode});
        	$this_row{$subfieldcode} .= GetAuthorisedValueDesc( $field->tag(),
                        $subfieldcode, $subfieldvalue, '', $tagslib) 
						|| $subfieldvalue;
        }

        if (($field->tag eq $branchtagfield) && ($subfieldcode eq $branchtagsubfield) && C4::Context->preference("IndependentBranches")) {
            #verifying rights
            my $userenv = C4::Context->userenv();
            unless (C4::Context->IsSuperLibrarian() or (($userenv->{'branch'} eq $subfieldvalue))){
                $this_row{'nomod'} = 1;
            }
        }
        $this_row{itemnumber} = $subfieldvalue if ($field->tag() eq $itemtagfield && $subfieldcode eq $itemtagsubfield);

        if ( C4::Context->preference('EasyAnalyticalRecords') ) {
            foreach my $hostitemnumber (@hostitemnumbers) {
                my $item = Koha::Items->find( $hostitemnumber );
                if ($this_row{itemnumber} eq $hostitemnumber) {
                    $this_row{hostitemflag} = 1;
                    $this_row{hostbiblionumber}= $item->biblio->biblionumber;
                    last;
                }
            }
        }
    }
    if (%this_row) {
        push(@big_array, \%this_row);
    }
}

my ($holdingbrtagf,$holdingbrtagsubf) = &GetMarcFromKohaField("items.holdingbranch",$frameworkcode);
@big_array = sort {$a->{$holdingbrtagsubf} cmp $b->{$holdingbrtagsubf}} @big_array;

# now, construct template !
# First, the existing items for display
my @item_value_loop;
my @header_value_loop;
for my $row ( @big_array ) {
    my %row_data;
    my @item_fields = map +{ field => $_ || '' }, @$row{ sort keys(%witness) };
    $row_data{item_value} = [ @item_fields ];
    $row_data{itemnumber} = $row->{itemnumber};
    #reporting this_row values
    $row_data{'nomod'} = $row->{'nomod'};
    $row_data{'hostitemflag'} = $row->{'hostitemflag'};
    $row_data{'hostbiblionumber'} = $row->{'hostbiblionumber'};
#	$row_data{'countanalytics'} = $row->{'countanalytics'};
    push(@item_value_loop,\%row_data);
}
foreach my $subfield_code (sort keys(%witness)) {
    my %header_value;
    $header_value{header_value} = $witness{$subfield_code};

    my $subfieldlib = $tagslib->{$itemtagfield}->{$subfield_code};
    my $kohafield = $subfieldlib->{kohafield};
    if ( $kohafield && $kohafield =~ /items.(.+)/ ) {
        $header_value{column_name} = $1;
    }

    push(@header_value_loop, \%header_value);
}

# now, build the item form for entering a new item
my @loop_data =();
my $i=0;

my $pref_itemcallnumber = C4::Context->preference('itemcallnumber');

my $branch = $input->param('branch') || C4::Context->userenv->{branch};
my $libraries = Koha::Libraries->search({}, { order_by => ['branchname'] })->unblessed;# build once ahead of time, instead of multiple times later.
for my $library ( @$libraries ) {
    $library->{selected} = 1 if $library->{branchcode} eq $branch
}

# We generate form, from actuel record
@fields = ();
if($itemrecord){
    foreach my $field ($itemrecord->fields()){
        my $tag = $field->{_tag};
        foreach my $subfield ( $field->subfields() ){

            my $subfieldtag = $subfield->[0];
            my $value       = $subfield->[1];
            my $subfieldlib = $tagslib->{$tag}->{$subfieldtag};

            next if ($tagslib->{$tag}->{$subfieldtag}->{'tab'} ne "10");

            my $subfield_data = generate_subfield_form($tag, $subfieldtag, $value, $tagslib, $subfieldlib, $libraries, $biblionumber, $temp, \@loop_data, $i, $restrictededition);
            push @fields, "$tag$subfieldtag";
            push (@loop_data, $subfield_data);
            $i++;
                    }

                }
            }
    # and now we add fields that are empty

# Using last created item if it exists

$itemrecord = $cookieitemrecord if ($prefillitem and not $justaddeditem and $op ne "edititem");

# We generate form, and fill with values if defined
foreach my $tag ( keys %{$tagslib}){
    foreach my $subtag (keys %{$tagslib->{$tag}}){
        next if IsMarcStructureInternal($tagslib->{$tag}{$subtag});
        next if ($tagslib->{$tag}->{$subtag}->{'tab'} ne "10");
        next if any { /^$tag$subtag$/ }  @fields;

        my @values = (undef);
        @values = $itemrecord->field($tag)->subfield($subtag) if ($itemrecord && defined($itemrecord->field($tag)) && defined($itemrecord->field($tag)->subfield($subtag)));
        for my $value (@values){
            my $subfield_data = generate_subfield_form($tag, $subtag, $value, $tagslib, $tagslib->{$tag}->{$subtag}, $libraries, $biblionumber, $temp, \@loop_data, $i, $restrictededition);
            push (@loop_data, $subfield_data);
            $i++;
        }
  }
}
@loop_data = sort {$a->{subfield} cmp $b->{subfield} } @loop_data;

my $item = Koha::Items->find($itemnumber); # We certainly want to fetch it earlier

# what's the next op ? it's what we are not in : an add if we're editing, otherwise, and edit.
$template->param(
    biblionumber => $biblionumber,
    title        => $oldrecord->{title},
    author       => $oldrecord->{author},
    item_loop        => \@item_value_loop,
    item_header_loop => \@header_value_loop,
    item             => \@loop_data,
    itemnumber       => $itemnumber,
    barcode          => $item ? $item->barcode : undef,
    itemtagfield     => $itemtagfield,
    itemtagsubfield  => $itemtagsubfield,
    op      => $nextop,
    opisadd => ($nextop eq "saveitem") ? 0 : 1,
    popup => scalar $input->param('popup') ? 1: 0,
    C4::Search::enabled_staff_search_views,
);
$template->{'VARS'}->{'searchid'} = $searchid;

if ($frameworkcode eq 'FA'){
    # fast cataloguing datas
    $template->param(
        'circborrowernumber' => $fa_circborrowernumber,
        'barcode'            => $fa_barcode,
        'branch'             => $fa_branch,
        'stickyduedate'      => $fa_stickyduedate,
        'duedatespec'        => $fa_duedatespec,
    );
}

foreach my $error (@errors) {
    $template->param($error => 1);
}
output_html_with_http_headers $input, $cookie, $template->output;
