#!/usr/bin/perl


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

use CGI qw ( -utf8 );
use Modern::Perl;
use C4::Auth;
use C4::Output;
use C4::Biblio;
use C4::Items;
use C4::Circulation;
use C4::Context;
use C4::Koha;
use C4::BackgroundJob;
use C4::ClassSource;
use C4::Debug;
use C4::Members;
use MARC::File::XML;
use List::MoreUtils qw/uniq/;

use Koha::AuthorisedValues;
use Koha::Biblios;
use Koha::DateUtils;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Patrons;

my $input = new CGI;
my $dbh = C4::Context->dbh;
my $error        = $input->param('error');
my @itemnumbers  = $input->multi_param('itemnumber');
my $biblionumber = $input->param('biblionumber');
my $op           = $input->param('op');
my $del          = $input->param('del');
my $del_records  = $input->param('del_records');
my $completedJobID = $input->param('completedJobID');
my $runinbackground = $input->param('runinbackground');
my $src          = $input->param('src');
my $use_default_values = $input->param('use_default_values');

my $template_name;
my $template_flag;
if (!defined $op) {
    $template_name = "tools/batchMod.tt";
    $template_flag = { tools => '*' };
    $op = q{};
} else {
    $template_name = ($del) ? "tools/batchMod-del.tt" : "tools/batchMod-edit.tt";
    $template_flag = ($del) ? { tools => 'items_batchdel' }   : { tools => 'items_batchmod' };
}


my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => $template_name,
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => $template_flag,
                 });

# Does the user have a restricted item edition permission?
my $uid = $loggedinuser ? Koha::Patrons->find( $loggedinuser )->userid : undef;
my $restrictededition = $uid ? haspermission($uid,  {'tools' => 'items_batchmod_restricted'}) : undef;
# In case user is a superlibrarian, edition is not restricted
$restrictededition = 0 if ($restrictededition != 0 && C4::Context->IsSuperLibrarian());

$template->param(del       => $del);

my $itemrecord;
my $nextop="";
my @errors; # store errors found while checking data BEFORE saving item.
my $items_display_hashref;
our $tagslib = &GetMarcStructure(1);

my $deleted_items = 0;     # Number of deleted items
my $deleted_records = 0;   # Number of deleted records ( with no items attached )
my $not_deleted_items = 0; # Number of items that could not be deleted
my @not_deleted;           # List of the itemnumbers that could not be deleted
my $modified_items = 0;    # Numbers of modified items
my $modified_fields = 0;   # Numbers of modified fields

my %cookies = parse CGI::Cookie($cookie);
my $sessionID = $cookies{'CGISESSID'}->value;


#--- ----------------------------------------------------------------------------
if ($op eq "action") {
#-------------------------------------------------------------------------------
    my @tags      = $input->multi_param('tag');
    my @subfields = $input->multi_param('subfield');
    my @values    = $input->multi_param('field_value');
    my @disabled  = $input->multi_param('disable_input');
    # build indicator hash.
    my @ind_tag   = $input->multi_param('ind_tag');
    my @indicator = $input->multi_param('indicator');

    # Is there something to modify ?
    # TODO : We shall use this var to warn the user in case no modification was done to the items
    my $values_to_modify = scalar(grep {!/^$/} @values);
    my $values_to_blank  = scalar(@disabled);
    my $marcitem;

    # Once the job is done
    if ($completedJobID) {
	# If we have a reasonable amount of items, we display them
    if (scalar(@itemnumbers) <= ( C4::Context->preference("MaxItemsToDisplayForBatchDel") // 1000 ) ) {
	    $items_display_hashref=BuildItemsData(@itemnumbers);
	} else {
	    # Else, we only display the barcode
        my @simple_items_display = map {
            my $itemnumber = $_;
            my $item = Koha::Items->find($itemnumber);
            {
                itemnumber   => $itemnumber,
                barcode      => $item ? ( $item->barcode // q{} ) : q{},
                biblionumber => $item ? $item->biblio->biblionumber : q{},
            };
        } @itemnumbers;
	    $template->param("simple_items_display" => \@simple_items_display);
	}

	# Setting the job as done
	my $job = C4::BackgroundJob->fetch($sessionID, $completedJobID);

	# Calling the template
        add_saved_job_results_to_template($template, $completedJobID);

    } else {
    # While the job is getting done

	# Job size is the number of items we have to process
	my $job_size = scalar(@itemnumbers);
	my $job = undef;

	# If we asked for background processing
	if ($runinbackground) {
	    $job = put_in_background($job_size);
	}

	#initializing values for updates
	my (  $itemtagfield,   $itemtagsubfield) = &GetMarcFromKohaField("items.itemnumber", "");
	if ($values_to_modify){
	    my $xml = TransformHtmlToXml(\@tags,\@subfields,\@values,\@indicator,\@ind_tag, 'ITEM');
	    $marcitem = MARC::Record::new_from_xml($xml, 'UTF-8');
        }
        if ($values_to_blank){
	    foreach my $disabledsubf (@disabled){
		if ($marcitem && $marcitem->field($itemtagfield)){
		    $marcitem->field($itemtagfield)->update( $disabledsubf => "" );
		}
		else {
		    $marcitem = MARC::Record->new();
		    $marcitem->append_fields( MARC::Field->new( $itemtagfield, '', '', $disabledsubf => "" ) );
		}
	    }
        }

	# For each item
	my $i = 1; 
	foreach my $itemnumber(@itemnumbers){

		$job->progress($i) if $runinbackground;
		my $itemdata = GetItem($itemnumber);
        if ( $del ){
            my $return = DelItemCheck( $itemdata->{'biblionumber'}, $itemdata->{'itemnumber'});
			if ($return == 1) {
			    $deleted_items++;
			} else {
			    $not_deleted_items++;
			    push @not_deleted,
				{ biblionumber => $itemdata->{'biblionumber'},
				  itemnumber => $itemdata->{'itemnumber'},
				  barcode => $itemdata->{'barcode'},
				  title => $itemdata->{'title'},
				  $return => 1
				};
			}

			# If there are no items left, delete the biblio
			if ( $del_records ) {
                            my $itemscount = Koha::Biblios->find( $itemdata->{'biblionumber'} )->items->count;
                            if ( $itemscount == 0 ) {
			        my $error = DelBiblio($itemdata->{'biblionumber'});
			        $deleted_records++ unless ( $error );
                            }
                        }
		} else {
            if ($values_to_modify || $values_to_blank) {
                my $localmarcitem = Item2Marc($itemdata);

                my $modified = UpdateMarcWith( $marcitem, $localmarcitem );
                if ( $modified ) {
                    eval {
                        if ( my $item = ModItemFromMarc( $localmarcitem, $itemdata->{biblionumber}, $itemnumber ) ) {
                            LostItem($itemnumber, 'batchmod') if $item->{itemlost} and not $itemdata->{itemlost};
                        }
                    };
                }
                if ( $runinbackground ) {
                    $modified_items++ if $modified;
                    $modified_fields += $modified;
                    $job->set({
                        modified_items  => $modified_items,
                        modified_fields => $modified_fields,
                    });
                }
		    }
		}
		$i++;
	}
    }
}
#
#-------------------------------------------------------------------------------
# build screen with existing items. and "new" one
#-------------------------------------------------------------------------------

if ($op eq "show"){
    my $filefh = $input->upload('uploadfile');
    my $filecontent = $input->param('filecontent');
    my ( @notfoundbarcodes, @notfounditemnumbers);

    my @contentlist;
    if ($filefh){
        binmode $filefh, ':encoding(UTF-8)';
        while (my $content=<$filefh>){
            $content =~ s/[\r\n]*$//;
            push @contentlist, $content if $content;
        }

        @contentlist = uniq @contentlist;
        if ($filecontent eq 'barcode_file') {
            my $existing_items = Koha::Items->search({ itemnumber => \@contentlist });
            @itemnumbers = $existing_items->get_column('itemnumber');
            my %exists = map {$_=>1} @{$existing_items->get_column('barcode')};
            @notfoundbarcodes = grep { !$exists{$_} } @contentlist;
        }
        elsif ( $filecontent eq 'itemid_file') {
            @itemnumbers = Koha::Items->search({ itemnumber => \@contentlist })->get_column('itemnumber');
            my %exists = map {$_=>1} @itemnumbers;
            @notfounditemnumbers = grep { !$exists{$_} } @contentlist;
        }
    } else {
        if (defined $biblionumber){
            my @all_items = GetItemsInfo( $biblionumber );
            foreach my $itm (@all_items) {
                push @itemnumbers, $itm->{itemnumber};
            }
        }
        if ( my $list=$input->param('barcodelist')){
            push my @barcodelist, uniq( split(/\s\n/, $list) );

            my $existing_items = Koha::Items->search({ barcode => \@barcodelist });
            @itemnumbers = $existing_items->get_column('itemnumber');
            my @barcodes = $existing_items->get_column('barcode');
            my %exists = map {$_=>1} @barcodes;
            @notfoundbarcodes = grep { !$exists{$_} } @barcodelist;
        }
    }

    # Flag to tell the template there are valid results, hidden or not
    if(scalar(@itemnumbers) > 0){ $template->param("itemresults" => 1); }
    # Only display the items if there are no more than pref MaxItemsToProcessForBatchMod or MaxItemsToDisplayForBatchDel
    my $max_items = $del
        ? C4::Context->preference("MaxItemsToDisplayForBatchDel")
        : C4::Context->preference("MaxItemsToProcessForBatchMod");
    if (scalar(@itemnumbers) <= ( $max_items // 1000 ) ) {
        $items_display_hashref=BuildItemsData(@itemnumbers);
    } else {
        $template->param("too_many_items" => scalar(@itemnumbers));
        # Even if we do not display the items, we need the itemnumbers
        $template->param(itemnumbers_array => \@itemnumbers);
    }
# now, build the item form for entering a new item
my @loop_data =();
my $i=0;
my $branch_limit = C4::Context->userenv ? C4::Context->userenv->{"branch"} : "";

my $libraries = Koha::Libraries->search({}, { order_by => ['branchname'] })->unblessed;# build once ahead of time, instead of multiple times later.

# Adding a default choice, in case the user does not want to modify the branch
my $nochange_branch = { branchname => '', value => '', selected => 1 };
unshift (@$libraries, $nochange_branch);

my $pref_itemcallnumber = C4::Context->preference('itemcallnumber');

# Getting list of subfields to keep when restricted batchmod edit is enabled
my $subfieldsToAllowForBatchmod = C4::Context->preference('SubfieldsToAllowForRestrictedBatchmod');
my $allowAllSubfields = (
    not defined $subfieldsToAllowForBatchmod
      or $subfieldsToAllowForBatchmod eq q||
) ? 1 : 0;
my @subfieldsToAllow = split(/ /, $subfieldsToAllowForBatchmod);

foreach my $tag (sort keys %{$tagslib}) {
    # loop through each subfield
    foreach my $subfield (sort keys %{$tagslib->{$tag}}) {
        next if IsMarcStructureInternal( $tagslib->{$tag}{$subfield} );
        next if (not $allowAllSubfields and $restrictededition && !grep { $tag . '$' . $subfield eq $_ } @subfieldsToAllow );
    	next if ($tagslib->{$tag}->{$subfield}->{'tab'} ne "10");
        # barcode and stocknumber are not meant to be batch-modified
    	next if $tagslib->{$tag}->{$subfield}->{'kohafield'} eq 'items.barcode';
    	next if $tagslib->{$tag}->{$subfield}->{'kohafield'} eq 'items.stocknumber';
	my %subfield_data;
 
	my $index_subfield = int(rand(1000000)); 
	if ($subfield eq '@'){
	    $subfield_data{id} = "tag_".$tag."_subfield_00_".$index_subfield;
	} else {
	    $subfield_data{id} = "tag_".$tag."_subfield_".$subfield."_".$index_subfield;
	}
	$subfield_data{tag}        = $tag;
	$subfield_data{subfield}   = $subfield;
	$subfield_data{marc_lib}   ="<span id=\"error$i\" title=\"".$tagslib->{$tag}->{$subfield}->{lib}."\">".$tagslib->{$tag}->{$subfield}->{lib}."</span>";
	$subfield_data{mandatory}  = $tagslib->{$tag}->{$subfield}->{mandatory};
	$subfield_data{repeatable} = $tagslib->{$tag}->{$subfield}->{repeatable};
	my ($x,$value);
   if ( $use_default_values) {
	    $value = $tagslib->{$tag}->{$subfield}->{defaultvalue};
	    # get today date & replace YYYY, MM, DD if provided in the default value
            my $today = dt_from_string;
            my $year  = $today->year;
            my $month = $today->month;
            my $day   = $today->day;
            $value =~ s/YYYY/$year/g;
            $value =~ s/MM/$month/g;
            $value =~ s/DD/$day/g;
	}
	$subfield_data{visibility} = "display:none;" if (($tagslib->{$tag}->{$subfield}->{hidden} > 4) || ($tagslib->{$tag}->{$subfield}->{hidden} < -4));
    # testing branch value if IndependentBranches.

	if ( $tagslib->{$tag}->{$subfield}->{authorised_value} ) {
	my @authorised_values;
	my %authorised_lib;
	# builds list, depending on authorised value...

    if ( $tagslib->{$tag}->{$subfield}->{authorised_value} eq "branches" ) {
        foreach my $library (@$libraries) {
            push @authorised_values, $library->{branchcode};
            $authorised_lib{$library->{branchcode}} = $library->{branchname};
        }
        $value = "";
    }
    elsif ( $tagslib->{$tag}->{$subfield}->{authorised_value} eq "itemtypes" ) {
        push @authorised_values, "";
        my $itemtypes = Koha::ItemTypes->search_with_localization;
        while ( my $itemtype = $itemtypes->next ) {
            push @authorised_values, $itemtype->itemtype;
            $authorised_lib{$itemtype->itemtype} = $itemtype->translated_description;
        }
        $value = "";

          #---- class_sources
      }
      elsif ( $tagslib->{$tag}->{$subfield}->{authorised_value} eq "cn_source" ) {
          push @authorised_values, "" unless ( $tagslib->{$tag}->{$subfield}->{mandatory} );
            
          my $class_sources = GetClassSources();
          my $default_source = C4::Context->preference("DefaultClassificationSource");
          
          foreach my $class_source (sort keys %$class_sources) {
              next unless $class_sources->{$class_source}->{'used'} or
                          ($value and $class_source eq $value)      or
                          ($class_source eq $default_source);
              push @authorised_values, $class_source;
              $authorised_lib{$class_source} = $class_sources->{$class_source}->{'description'};
          }
		  $value = '';

          #---- "true" authorised value
      }
      else {
          push @authorised_values, ""; # unless ( $tagslib->{$tag}->{$subfield}->{mandatory} );

          my @avs = Koha::AuthorisedValues->search({ category => $tagslib->{$tag}->{$subfield}->{authorised_value}, branchcode => $branch_limit },{order_by=>'lib'});
          for my $av ( @avs ) {
              push @authorised_values, $av->authorised_value;
              $authorised_lib{$av->authorised_value} = $av->lib;
          }
          $value="";
      }
        $subfield_data{marc_value} = {
            type    => 'select',
            id      => "tag_".$tag."_subfield_".$subfield."_".$index_subfield,
            name    => "field_value",
            values  => \@authorised_values,
            labels  => \%authorised_lib,
            default => $value,
        };
    # it's a thesaurus / authority field
    }
    elsif ( $tagslib->{$tag}->{$subfield}->{authtypecode} ) {
        $subfield_data{marc_value} = {
            type         => 'text1',
            id           => $subfield_data{id},
            value        => $value,
            authtypecode => $tagslib->{$tag}->{$subfield}->{authtypecode},
        }
    }
    elsif ( $tagslib->{$tag}->{$subfield}->{value_builder} ) { # plugin
        require Koha::FrameworkPlugin;
        my $plugin = Koha::FrameworkPlugin->new( {
            name => $tagslib->{$tag}->{$subfield}->{'value_builder'},
            item_style => 1,
        });
        my $temp;
        my $pars= { dbh => $dbh, record => $temp, tagslib => $tagslib,
            id => $subfield_data{id}, tabloop => \@loop_data };
        $plugin->build( $pars );
        if( !$plugin->errstr ) {
            $subfield_data{marc_value} = {
                type       => 'text2',
                id         => $subfield_data{id},
                value      => $value,
                javascript => $plugin->javascript,
                noclick    => $plugin->noclick,
            };
        } else {
            warn $plugin->errstr;
            $subfield_data{marc_value} = { # supply default input form
                type       => 'text',
                id         => $subfield_data{id},
                value      => $value,
            };
        }
    }
    elsif ( $tag eq '' ) {       # it's an hidden field
            $subfield_data{marc_value} = {
                type       => 'hidden',
                id         => $subfield_data{id},
                value      => $value,
            };
    }
    elsif ( $tagslib->{$tag}->{$subfield}->{'hidden'} ) {   # FIXME: shouldn't input type be "hidden" ?
        $subfield_data{marc_value} = {
                type       => 'text',
                id         => $subfield_data{id},
                value      => $value,
        };
    }
    elsif ( length($value) > 100
            or (C4::Context->preference("marcflavour") eq "UNIMARC" and
                  300 <= $tag && $tag < 400 && $subfield eq 'a' )
            or (C4::Context->preference("marcflavour") eq "MARC21"  and
                  500 <= $tag && $tag < 600                     )
          ) {
        # oversize field (textarea)
        $subfield_data{marc_value} = {
                type       => 'textarea',
                id         => $subfield_data{id},
                value      => $value,
        };
    } else {
        # it's a standard field
        $subfield_data{marc_value} = {
                type       => 'text',
                id         => $subfield_data{id},
                value      => $value,
        };
    }
#   $subfield_data{marc_value}="<input type=\"text\" name=\"field_value\">";
    push (@loop_data, \%subfield_data);
    $i++
  }
} # -- End foreach tag



    # what's the next op ? it's what we are not in : an add if we're editing, otherwise, and edit.
    $template->param(
        item                => \@loop_data,
        notfoundbarcodes    => \@notfoundbarcodes,
        notfounditemnumbers => \@notfounditemnumbers
    );
    $nextop="action"
} # -- End action="show"

$template->param(%$items_display_hashref) if $items_display_hashref;
$template->param(
    op      => $nextop,
);
$template->param( $op => 1 ) if $op;

if ($op eq "action") {

    #my @not_deleted_loop = map{{itemnumber=>$_}}@not_deleted;

    $template->param(
	not_deleted_items => $not_deleted_items,
	deleted_items => $deleted_items,
	delete_records => $del_records,
	deleted_records => $deleted_records,
	not_deleted_loop => \@not_deleted 
    );
}

foreach my $error (@errors) {
    $template->param($error => 1) if $error;
}
$template->param(src => $src);
$template->param(biblionumber => $biblionumber);
output_html_with_http_headers $input, $cookie, $template->output;
exit;


# ---------------- Functions

sub BuildItemsData{
	my @itemnumbers=@_;
		# now, build existiing item list
		my %witness; #---- stores the list of subfields used at least once, with the "meaning" of the code
		my @big_array;
		#---- finds where items.itemnumber is stored
		my (  $itemtagfield,   $itemtagsubfield) = &GetMarcFromKohaField("items.itemnumber", "");
		my ($branchtagfield, $branchtagsubfield) = &GetMarcFromKohaField("items.homebranch", "");
		foreach my $itemnumber (@itemnumbers){
			my $itemdata=GetItem($itemnumber);
			my $itemmarc=Item2Marc($itemdata);
			my %this_row;
			foreach my $field (grep {$_->tag() eq $itemtagfield} $itemmarc->fields()) {
				# loop through each subfield
				my $itembranchcode=$field->subfield($branchtagsubfield);
                if ($itembranchcode && C4::Context->preference("IndependentBranches")) {
						#verifying rights
						my $userenv = C4::Context->userenv();
                        unless (C4::Context->IsSuperLibrarian() or (($userenv->{'branch'} eq $itembranchcode))){
								$this_row{'nomod'}=1;
						}
				}
				my $tag=$field->tag();
				foreach my $subfield ($field->subfields) {
					my ($subfcode,$subfvalue)=@$subfield;
					next if ($tagslib->{$tag}->{$subfcode}->{tab} ne 10 
							&& $tag        ne $itemtagfield 
							&& $subfcode   ne $itemtagsubfield);

					$witness{$subfcode} = $tagslib->{$tag}->{$subfcode}->{lib} if ($tagslib->{$tag}->{$subfcode}->{tab}  eq 10);
					if ($tagslib->{$tag}->{$subfcode}->{tab}  eq 10) {
						$this_row{$subfcode}=GetAuthorisedValueDesc( $tag,
									$subfcode, $subfvalue, '', $tagslib) 
									|| $subfvalue;
					}

					$this_row{itemnumber} = $subfvalue if ($tag eq $itemtagfield && $subfcode eq $itemtagsubfield);
				}
			}

            # grab title, author, and ISBN to identify bib that the item
            # belongs to in the display
            my $biblio = Koha::Biblios->find( $itemdata->{biblionumber} );
            $this_row{title}        = $biblio->title;
            $this_row{author}       = $biblio->author;
            $this_row{isbn}         = $biblio->biblioitem->isbn;
            $this_row{biblionumber} = $biblio->biblionumber;
            $this_row{holds}        = $biblio->holds->count;
            $this_row{item_holds}   = Koha::Holds->search( itemnumber => $itemnumber )->count;

			if (%this_row) {
				push(@big_array, \%this_row);
			}
		}
		@big_array = sort {$a->{0} cmp $b->{0}} @big_array;

		# now, construct template !
		# First, the existing items for display
		my @item_value_loop;
		my @witnesscodessorted=sort keys %witness;
		for my $row ( @big_array ) {
			my %row_data;
			my @item_fields = map +{ field => $_ || '' }, @$row{ @witnesscodessorted };
			$row_data{item_value} = [ @item_fields ];
			$row_data{itemnumber} = $row->{itemnumber};
			#reporting this_row values
			$row_data{'nomod'} = $row->{'nomod'};
      $row_data{bibinfo} = $row->{bibinfo};
      $row_data{author} = $row->{author};
      $row_data{title} = $row->{title};
      $row_data{isbn} = $row->{isbn};
      $row_data{biblionumber} = $row->{biblionumber};
      $row_data{holds}        = $row->{holds};
      $row_data{item_holds}   = $row->{item_holds};
      my $is_on_loan = C4::Circulation::IsItemIssued( $row->{itemnumber} );
      $row_data{onloan} = $is_on_loan ? 1 : 0;
			push(@item_value_loop,\%row_data);
		}
		my @header_loop=map { { header_value=> $witness{$_}} } @witnesscodessorted;

	return { item_loop        => \@item_value_loop, item_header_loop => \@header_loop };
}

#BE WARN : it is not the general case 
# This function can be OK in the item marc record special case
# Where subfield is not repeated
# And where we are sure that field should correspond
# And $tag>10
sub UpdateMarcWith {
  my ($marcfrom,$marcto)=@_;
    my (  $itemtag,   $itemtagsubfield) = &GetMarcFromKohaField("items.itemnumber", "");
    my $fieldfrom=$marcfrom->field($itemtag);
    my @fields_to=$marcto->field($itemtag);
    my $modified = 0;
    foreach my $subfield ( $fieldfrom->subfields() ) {
        foreach my $field_to_update ( @fields_to ) {
            if ( $subfield->[1] ) {
                unless ( $field_to_update->subfield($subfield->[0]) eq $subfield->[1] ) {
                    $modified++;
                    $field_to_update->update( $subfield->[0] => $subfield->[1] );
                }
            }
            else {
                $modified++;
                $field_to_update->delete_subfield( code => $subfield->[0] );
            }
        }
    }
    return $modified;
}

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

# ----------------------------
# Background functions


sub add_results_to_template {
    my $template = shift;
    my $results = shift;
    $template->param(map { $_ => $results->{$_} } keys %{ $results });
}

sub add_saved_job_results_to_template {
    my $template = shift;
    my $completedJobID = shift;
    my $job = C4::BackgroundJob->fetch($sessionID, $completedJobID);
    my $results = $job->results();
    add_results_to_template($template, $results);

    my $fields = $job->get("modified_fields");
    my $items = $job->get("modified_items");
    $template->param(
        modified_items => $items,
        modified_fields => $fields,
    );
}

sub put_in_background {
    my $job_size = shift;

    my $job = C4::BackgroundJob->new($sessionID, "test", '/cgi-bin/koha/tools/batchMod.pl', $job_size);
    my $jobID = $job->id();

    # fork off
    if (my $pid = fork) {
        # parent
        # return job ID as JSON

        # prevent parent exiting from
        # destroying the kid's database handle
        # FIXME: according to DBI doc, this may not work for Oracle
        $dbh->{InactiveDestroy}  = 1;

        my $reply = CGI->new("");
        print $reply->header(-type => 'text/html');
        print '{"jobID":"' . $jobID . '"}';
        exit 0;
    } elsif (defined $pid) {
        # child
        # close STDOUT to signal to Apache that
        # we're now running in the background
        close STDOUT;
        close STDERR;
    } else {
        # fork failed, so exit immediately
        warn "fork failed while attempting to run tools/batchMod.pl as a background job";
        exit 0;
    }
    return $job;
}



