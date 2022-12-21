package Koha::Item;

# Copyright ByWater Solutions 2014
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

use List::MoreUtils qw( any );

use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );

use C4::Context;
use C4::Circulation qw( barcodedecode GetBranchItemRule );
use C4::Reserves;
use C4::ClassSource qw( GetClassSort );
use C4::Log qw( logaction );

use Koha::Checkouts;
use Koha::CirculationRules;
use Koha::CoverImages;
use Koha::SearchEngine::Indexer;
use Koha::Exceptions::Item::Transfer;
use Koha::Item::Transfer::Limits;
use Koha::Item::Transfers;
use Koha::Item::Attributes;
use Koha::ItemTypes;
use Koha::Patrons;
use Koha::Plugins;
use Koha::Libraries;
use Koha::StockRotationItem;
use Koha::StockRotationRotas;
use Koha::TrackedLinks;

use base qw(Koha::Object);

=head1 NAME

Koha::Item - Koha Item object class

=head1 API

=head2 Class methods

=cut

=head3 store

    $item->store;

$params can take an optional 'skip_record_index' parameter.
If set, the reindexation process will not happen (index_records not called)

NOTE: This is a temporary fix to answer a performance issue when lot of items
are added (or modified) at the same time.
The correct way to fix this is to make the ES reindexation process async.
You should not turn it on if you do not understand what it is doing exactly.

=cut

sub store {
    my $self = shift;
    my $params = @_ ? shift : {};

    my $log_action = $params->{log_action} // 1;

    # We do not want to oblige callers to pass this value
    # Dev conveniences vs performance?
    unless ( $self->biblioitemnumber ) {
        $self->biblioitemnumber( $self->biblio->biblioitem->biblioitemnumber );
    }

    # See related changes from C4::Items::AddItem
    unless ( $self->itype ) {
        $self->itype($self->biblio->biblioitem->itemtype);
    }

    $self->barcode( C4::Circulation::barcodedecode( $self->barcode ) );

    my $today  = dt_from_string;
    my $action = 'create';

    unless ( $self->in_storage ) { #AddItem

        unless ( $self->permanent_location ) {
            $self->permanent_location($self->location);
        }

        my $default_location = C4::Context->preference('NewItemsDefaultLocation');
        unless ( $self->location || !$default_location ) {
            $self->permanent_location( $self->location || $default_location )
              unless $self->permanent_location;
            $self->location($default_location);
        }

        unless ( $self->replacementpricedate ) {
            $self->replacementpricedate($today);
        }
        unless ( $self->datelastseen ) {
            $self->datelastseen($today);
        }

        unless ( $self->dateaccessioned ) {
            $self->dateaccessioned($today);
        }

        if (   $self->itemcallnumber
            or $self->cn_source )
        {
            my $cn_sort = GetClassSort( $self->cn_source, $self->itemcallnumber, "" );
            $self->cn_sort($cn_sort);
        }

    } else { # ModItem

        $action = 'modify';

        my %updated_columns = $self->_result->get_dirty_columns;
        return $self->SUPER::store unless %updated_columns;

        # Retrieve the item for comparison if we need to
        my $pre_mod_item = (
                 exists $updated_columns{itemlost}
              or exists $updated_columns{withdrawn}
              or exists $updated_columns{damaged}
        ) ? $self->get_from_storage : undef;

        # Update *_on  fields if needed
        # FIXME: Why not for AddItem as well?
        my @fields = qw( itemlost withdrawn damaged );
        for my $field (@fields) {

            # If the field is defined but empty or 0, we are
            # removing/unsetting and thus need to clear out
            # the 'on' field
            if (   exists $updated_columns{$field}
                && defined( $self->$field )
                && !$self->$field )
            {
                my $field_on = "${field}_on";
                $self->$field_on(undef);
            }
            # If the field has changed otherwise, we much update
            # the 'on' field
            elsif (exists $updated_columns{$field}
                && $updated_columns{$field}
                && !$pre_mod_item->$field )
            {
                my $field_on = "${field}_on";
                $self->$field_on(
                    DateTime::Format::MySQL->format_datetime(
                        dt_from_string()
                    )
                );
            }
        }

        if (   exists $updated_columns{itemcallnumber}
            or exists $updated_columns{cn_source} )
        {
            my $cn_sort = GetClassSort( $self->cn_source, $self->itemcallnumber, "" );
            $self->cn_sort($cn_sort);
        }


        if (    exists $updated_columns{location}
            and $self->location ne 'CART'
            and $self->location ne 'PROC'
            and not exists $updated_columns{permanent_location} )
        {
            $self->permanent_location( $self->location );
        }

        # If item was lost and has now been found,
        # reverse any list item charges if necessary.
        if (    exists $updated_columns{itemlost}
            and $updated_columns{itemlost} <= 0
            and $pre_mod_item->itemlost > 0 )
        {
            $self->_set_found_trigger($pre_mod_item);
        }

    }

    my $result = $self->SUPER::store;
    if ( $log_action && C4::Context->preference("CataloguingLog") ) {
        $action eq 'create'
          ? logaction( "CATALOGUING", "ADD", $self->itemnumber, "item" )
          : logaction( "CATALOGUING", "MODIFY", $self->itemnumber, $self );
    }
    my $indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
    $indexer->index_records( $self->biblionumber, "specialUpdate", "biblioserver" )
        unless $params->{skip_record_index};
    $self->get_from_storage->_after_item_action_hooks({ action => $action });

    return $result;
}

=head3 delete

=cut

sub delete {
    my $self = shift;
    my $params = @_ ? shift : {};

    # FIXME check the item has no current issues
    # i.e. raise the appropriate exception

    my $result = $self->SUPER::delete;

    my $indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
    $indexer->index_records( $self->biblionumber, "specialUpdate", "biblioserver" )
        unless $params->{skip_record_index};

    $self->_after_item_action_hooks({ action => 'delete' });

    logaction( "CATALOGUING", "DELETE", $self->itemnumber, "item" )
      if C4::Context->preference("CataloguingLog");

    return $result;
}

=head3 safe_delete

=cut

sub safe_delete {
    my $self = shift;
    my $params = @_ ? shift : {};

    my $safe_to_delete = $self->safe_to_delete;
    return $safe_to_delete unless $safe_to_delete eq '1';

    $self->move_to_deleted;

    return $self->delete($params);
}

=head3 safe_to_delete

returns 1 if the item is safe to delete,

"book_on_loan" if the item is checked out,

"not_same_branch" if the item is blocked by independent branches,

"book_reserved" if the there are holds aganst the item, or

"linked_analytics" if the item has linked analytic records.

"last_item_for_hold" if the item is the last one on a record on which a biblio-level hold is placed

=cut

sub safe_to_delete {
    my ($self) = @_;

    return "book_on_loan" if $self->checkout;

    return "not_same_branch"
      if defined C4::Context->userenv
      and !C4::Context->IsSuperLibrarian()
      and C4::Context->preference("IndependentBranches")
      and ( C4::Context->userenv->{branch} ne $self->homebranch );

    # check it doesn't have a waiting reserve
    return "book_reserved"
      if $self->holds->search( { found => [ 'W', 'T' ] } )->count;

    return "linked_analytics"
      if C4::Items::GetAnalyticsCount( $self->itemnumber ) > 0;

    return "last_item_for_hold"
      if $self->biblio->items->count == 1
      && $self->biblio->holds->search(
          {
              itemnumber => undef,
          }
        )->count;

    return 1;
}

=head3 move_to_deleted

my $is_moved = $item->move_to_deleted;

Move an item to the deleteditems table.
This can be done before deleting an item, to make sure the data are not completely deleted.

=cut

sub move_to_deleted {
    my ($self) = @_;
    my $item_infos = $self->unblessed;
    delete $item_infos->{timestamp}; #This ensures the timestamp date in deleteditems will be set to the current timestamp
    return Koha::Database->new->schema->resultset('Deleteditem')->create($item_infos);
}


=head3 effective_itemtype

Returns the itemtype for the item based on whether item level itemtypes are set or not.

=cut

sub effective_itemtype {
    my ( $self ) = @_;

    return $self->_result()->effective_itemtype();
}

=head3 home_branch

=cut

sub home_branch {
    my ($self) = @_;

    $self->{_home_branch} ||= Koha::Libraries->find( $self->homebranch() );

    return $self->{_home_branch};
}

=head3 holding_branch

=cut

sub holding_branch {
    my ($self) = @_;

    $self->{_holding_branch} ||= Koha::Libraries->find( $self->holdingbranch() );

    return $self->{_holding_branch};
}

=head3 biblio

my $biblio = $item->biblio;

Return the bibliographic record of this item

=cut

sub biblio {
    my ( $self ) = @_;
    my $biblio_rs = $self->_result->biblio;
    return Koha::Biblio->_new_from_dbic( $biblio_rs );
}

=head3 biblioitem

my $biblioitem = $item->biblioitem;

Return the biblioitem record of this item

=cut

sub biblioitem {
    my ( $self ) = @_;
    my $biblioitem_rs = $self->_result->biblioitem;
    return Koha::Biblioitem->_new_from_dbic( $biblioitem_rs );
}

=head3 checkout

my $checkout = $item->checkout;

Return the checkout for this item

=cut

sub checkout {
    my ( $self ) = @_;
    my $checkout_rs = $self->_result->issue;
    return unless $checkout_rs;
    return Koha::Checkout->_new_from_dbic( $checkout_rs );
}

=head3 holds

my $holds = $item->holds();
my $holds = $item->holds($params);
my $holds = $item->holds({ found => 'W'});

Return holds attached to an item, optionally accept a hashref of params to pass to search

=cut

sub holds {
    my ( $self,$params ) = @_;
    my $holds_rs = $self->_result->reserves->search($params);
    return Koha::Holds->_new_from_dbic( $holds_rs );
}

=head3 request_transfer

  my $transfer = $item->request_transfer(
    {
        to     => $to_library,
        reason => $reason,
        [ ignore_limits => 0, enqueue => 1, replace => 1 ]
    }
  );

Add a transfer request for this item to the given branch for the given reason.

An exception will be thrown if the BranchTransferLimits would prevent the requested
transfer, unless 'ignore_limits' is passed to override the limits.

An exception will be thrown if an active transfer (i.e pending arrival date) is found;
The caller should catch such cases and retry the transfer request as appropriate passing
an appropriate override.

Overrides
* enqueue - Used to queue up the transfer when the existing transfer is found to be in transit.
* replace - Used to replace the existing transfer request with your own.

=cut

sub request_transfer {
    my ( $self, $params ) = @_;

    # check for mandatory params
    my @mandatory = ( 'to', 'reason' );
    for my $param (@mandatory) {
        unless ( defined( $params->{$param} ) ) {
            Koha::Exceptions::MissingParameter->throw(
                error => "The $param parameter is mandatory" );
        }
    }

    Koha::Exceptions::Item::Transfer::Limit->throw()
      unless ( $params->{ignore_limits}
        || $self->can_be_transferred( { to => $params->{to} } ) );

    my $request = $self->get_transfer;
    Koha::Exceptions::Item::Transfer::InQueue->throw( transfer => $request )
      if ( $request && !$params->{enqueue} && !$params->{replace} );

    $request->cancel( { reason => $params->{reason}, force => 1 } )
      if ( defined($request) && $params->{replace} );

    my $transfer = Koha::Item::Transfer->new(
        {
            itemnumber    => $self->itemnumber,
            daterequested => dt_from_string,
            frombranch    => $self->holdingbranch,
            tobranch      => $params->{to}->branchcode,
            reason        => $params->{reason},
            comments      => $params->{comment}
        }
    )->store();

    return $transfer;
}

=head3 get_transfer

  my $transfer = $item->get_transfer;

Return the active transfer request or undef

Note: Transfers are retrieved in a Modified FIFO (First In First Out) order
whereby the most recently sent, but not received, transfer will be returned
if it exists, otherwise the oldest unsatisfied transfer will be returned.

This allows for transfers to queue, which is the case for stock rotation and
rotating collections where a manual transfer may need to take precedence but
we still expect the item to end up at a final location eventually.

=cut

sub get_transfer {
    my ($self) = @_;
    my $transfer_rs = $self->_result->branchtransfers->search(
        {
            datearrived   => undef,
            datecancelled => undef
        },
        {
            order_by =>
              [ { -desc => 'datesent' }, { -asc => 'daterequested' } ],
            rows => 1
        }
    )->first;
    return unless $transfer_rs;
    return Koha::Item::Transfer->_new_from_dbic($transfer_rs);
}

=head3 get_transfers

  my $transfer = $item->get_transfers;

Return the list of outstanding transfers (i.e requested but not yet cancelled
or received).

Note: Transfers are retrieved in a Modified FIFO (First In First Out) order
whereby the most recently sent, but not received, transfer will be returned
first if it exists, otherwise requests are in oldest to newest request order.

This allows for transfers to queue, which is the case for stock rotation and
rotating collections where a manual transfer may need to take precedence but
we still expect the item to end up at a final location eventually.

=cut

sub get_transfers {
    my ($self) = @_;
    my $transfer_rs = $self->_result->branchtransfers->search(
        {
            datearrived   => undef,
            datecancelled => undef
        },
        {
            order_by =>
              [ { -desc => 'datesent' }, { -asc => 'daterequested' } ],
        }
    );
    return Koha::Item::Transfers->_new_from_dbic($transfer_rs);
}

=head3 last_returned_by

Gets and sets the last borrower to return an item.

Accepts and returns Koha::Patron objects

$item->last_returned_by( $borrowernumber );

$last_returned_by = $item->last_returned_by();

=cut

sub last_returned_by {
    my ( $self, $borrower ) = @_;

    my $items_last_returned_by_rs = Koha::Database->new()->schema()->resultset('ItemsLastBorrower');

    if ($borrower) {
        return $items_last_returned_by_rs->update_or_create(
            { borrowernumber => $borrower->borrowernumber, itemnumber => $self->id } );
    }
    else {
        unless ( $self->{_last_returned_by} ) {
            my $result = $items_last_returned_by_rs->single( { itemnumber => $self->id } );
            if ($result) {
                $self->{_last_returned_by} = Koha::Patrons->find( $result->get_column('borrowernumber') );
            }
        }

        return $self->{_last_returned_by};
    }
}

=head3 can_article_request

my $bool = $item->can_article_request( $borrower )

Returns true if item can be specifically requested

$borrower must be a Koha::Patron object

=cut

sub can_article_request {
    my ( $self, $borrower ) = @_;

    my $rule = $self->article_request_type($borrower);

    return 1 if $rule && $rule ne 'no' && $rule ne 'bib_only';
    return q{};
}

=head3 hidden_in_opac

my $bool = $item->hidden_in_opac({ [ rules => $rules ] })

Returns true if item fields match the hidding criteria defined in $rules.
Returns false otherwise.

Takes HASHref that can have the following parameters:
    OPTIONAL PARAMETERS:
    $rules : { <field> => [ value_1, ... ], ... }

Note: $rules inherits its structure from the parsed YAML from reading
the I<OpacHiddenItems> system preference.

=cut

sub hidden_in_opac {
    my ( $self, $params ) = @_;

    my $rules = $params->{rules} // {};

    return 1
        if C4::Context->preference('hidelostitems') and
           $self->itemlost > 0;

    my $hidden_in_opac = 0;

    foreach my $field ( keys %{$rules} ) {

        if ( any { $self->$field eq $_ } @{ $rules->{$field} } ) {
            $hidden_in_opac = 1;
            last;
        }
    }

    return $hidden_in_opac;
}

=head3 can_be_transferred

$item->can_be_transferred({ to => $to_library, from => $from_library })
Checks if an item can be transferred to given library.

This feature is controlled by two system preferences:
UseBranchTransferLimits to enable / disable the feature
BranchTransferLimitsType to use either an itemnumber or ccode as an identifier
                         for setting the limitations

Takes HASHref that can have the following parameters:
    MANDATORY PARAMETERS:
    $to   : Koha::Library
    OPTIONAL PARAMETERS:
    $from : Koha::Library  # if not given, item holdingbranch
                           # will be used instead

Returns 1 if item can be transferred to $to_library, otherwise 0.

To find out whether at least one item of a Koha::Biblio can be transferred, please
see Koha::Biblio->can_be_transferred() instead of using this method for
multiple items of the same biblio.

=cut

sub can_be_transferred {
    my ($self, $params) = @_;

    my $to   = $params->{to};
    my $from = $params->{from};

    $to   = $to->branchcode;
    $from = defined $from ? $from->branchcode : $self->holdingbranch;

    return 1 if $from eq $to; # Transfer to current branch is allowed
    return 1 unless C4::Context->preference('UseBranchTransferLimits');

    my $limittype = C4::Context->preference('BranchTransferLimitsType');
    return Koha::Item::Transfer::Limits->search({
        toBranch => $to,
        fromBranch => $from,
        $limittype => $limittype eq 'itemtype'
                        ? $self->effective_itemtype : $self->ccode
    })->count ? 0 : 1;

}

=head3 pickup_locations

$pickup_locations = $item->pickup_locations( {patron => $patron } )

Returns possible pickup locations for this item, according to patron's home library (if patron is defined and holds are allowed only from hold groups)
and if item can be transferred to each pickup location.

=cut

sub pickup_locations {
    my ($self, $params) = @_;

    my $patron = $params->{patron};

    my $circ_control_branch =
      C4::Reserves::GetReservesControlBranch( $self->unblessed(), $patron->unblessed );
    my $branchitemrule =
      C4::Circulation::GetBranchItemRule( $circ_control_branch, $self->itype );

    if(defined $patron) {
        return Koha::Libraries->new()->empty if $branchitemrule->{holdallowed} eq 'from_local_hold_group' && !$self->home_branch->validate_hold_sibling( {branchcode => $patron->branchcode} );
        return Koha::Libraries->new()->empty if $branchitemrule->{holdallowed} eq 'from_home_library' && $self->home_branch->branchcode ne $patron->branchcode;
    }

    my $pickup_libraries = Koha::Libraries->search();
    if ($branchitemrule->{hold_fulfillment_policy} eq 'holdgroup') {
        $pickup_libraries = $self->home_branch->get_hold_libraries;
    } elsif ($branchitemrule->{hold_fulfillment_policy} eq 'patrongroup') {
        my $plib = Koha::Libraries->find({ branchcode => $patron->branchcode});
        $pickup_libraries = $plib->get_hold_libraries;
    } elsif ($branchitemrule->{hold_fulfillment_policy} eq 'homebranch') {
        $pickup_libraries = Koha::Libraries->search({ branchcode => $self->homebranch });
    } elsif ($branchitemrule->{hold_fulfillment_policy} eq 'holdingbranch') {
        $pickup_libraries = Koha::Libraries->search({ branchcode => $self->holdingbranch });
    };

    return $pickup_libraries->search(
        {
            pickup_location => 1
        },
        {
            order_by => ['branchname']
        }
    ) unless C4::Context->preference('UseBranchTransferLimits');

    my $limittype = C4::Context->preference('BranchTransferLimitsType');
    my ($ccode, $itype) = (undef, undef);
    if( $limittype eq 'ccode' ){
        $ccode = $self->ccode;
    } else {
        $itype = $self->itype;
    }
    my $limits = Koha::Item::Transfer::Limits->search(
        {
            fromBranch => $self->holdingbranch,
            ccode      => $ccode,
            itemtype   => $itype,
        },
        { columns => ['toBranch'] }
    );

    return $pickup_libraries->search(
        {
            pickup_location => 1,
            branchcode      => {
                '-not_in' => $limits->_resultset->as_query
            }
        },
        {
            order_by => ['branchname']
        }
    );
}

=head3 article_request_type

my $type = $item->article_request_type( $borrower )

returns 'yes', 'no', 'bib_only', or 'item_only'

$borrower must be a Koha::Patron object

=cut

sub article_request_type {
    my ( $self, $borrower ) = @_;

    my $branch_control = C4::Context->preference('HomeOrHoldingBranch');
    my $branchcode =
        $branch_control eq 'homebranch'    ? $self->homebranch
      : $branch_control eq 'holdingbranch' ? $self->holdingbranch
      :                                      undef;
    my $borrowertype = $borrower->categorycode;
    my $itemtype = $self->effective_itemtype();
    my $rule = Koha::CirculationRules->get_effective_rule(
        {
            rule_name    => 'article_requests',
            categorycode => $borrowertype,
            itemtype     => $itemtype,
            branchcode   => $branchcode
        }
    );

    return q{} unless $rule;
    return $rule->rule_value || q{}
}

=head3 current_holds

=cut

sub current_holds {
    my ( $self ) = @_;
    my $attributes = { order_by => 'priority' };
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my $params = {
        itemnumber => $self->itemnumber,
        suspend => 0,
        -or => [
            reservedate => { '<=' => $dtf->format_date(dt_from_string) },
            waitingdate => { '!=' => undef },
        ],
    };
    my $hold_rs = $self->_result->reserves->search( $params, $attributes );
    return Koha::Holds->_new_from_dbic($hold_rs);
}

=head3 stockrotationitem

  my $sritem = Koha::Item->stockrotationitem;

Returns the stock rotation item associated with the current item.

=cut

sub stockrotationitem {
    my ( $self ) = @_;
    my $rs = $self->_result->stockrotationitem;
    return 0 if !$rs;
    return Koha::StockRotationItem->_new_from_dbic( $rs );
}

=head3 add_to_rota

  my $item = $item->add_to_rota($rota_id);

Add this item to the rota identified by $ROTA_ID, which means associating it
with the first stage of that rota.  Should this item already be associated
with a rota, then we will move it to the new rota.

=cut

sub add_to_rota {
    my ( $self, $rota_id ) = @_;
    Koha::StockRotationRotas->find($rota_id)->add_item($self->itemnumber);
    return $self;
}

=head3 has_pending_hold

  my $is_pending_hold = $item->has_pending_hold();

This method checks the tmp_holdsqueue to see if this item has been selected for a hold, but not filled yet and returns true or false

=cut

sub has_pending_hold {
    my ( $self ) = @_;
    my $pending_hold = $self->_result->tmp_holdsqueues;
    return $pending_hold->count ? 1: 0;
}

=head3 as_marc_field

    my $field = $item->as_marc_field;

This method returns a MARC::Field object representing the Koha::Item object
with the current mappings configuration.

=cut

sub as_marc_field {
    my ( $self ) = @_;

    my ( $itemtag, $itemtagsubfield) = C4::Biblio::GetMarcFromKohaField( "items.itemnumber" );

    my $tagslib = C4::Biblio::GetMarcStructure( 1, $self->biblio->frameworkcode, { unsafe => 1 });

    my @subfields;

    my $item_field = $tagslib->{$itemtag};

    my $more_subfields = $self->additional_attributes->to_hashref;
    foreach my $subfield (
        sort {
               $a->{display_order} <=> $b->{display_order}
            || $a->{subfield} cmp $b->{subfield}
        } grep { ref($_) && %$_ } values %$item_field
    ){

        my $kohafield = $subfield->{kohafield};
        my $tagsubfield = $subfield->{tagsubfield};
        my $value;
        if ( defined $kohafield ) {
            next if $kohafield !~ m{^items\.}; # That would be weird!
            ( my $attribute = $kohafield ) =~ s|^items\.||;
            $value = $self->$attribute # This call may fail if a kohafield is not a DB column but we don't want to add extra work for that there
                if defined $self->$attribute and $self->$attribute ne '';
        } else {
            $value = $more_subfields->{$tagsubfield}
        }

        next unless defined $value
            and $value ne q{};

        if ( $subfield->{repeatable} ) {
            my @values = split '\|', $value;
            push @subfields, ( $tagsubfield => $_ ) for @values;
        }
        else {
            push @subfields, ( $tagsubfield => $value );
        }

    }

    return unless @subfields;

    return MARC::Field->new(
        "$itemtag", ' ', ' ', @subfields
    );
}

=head3 renewal_branchcode

Returns the branchcode to be recorded in statistics renewal of the item

=cut

sub renewal_branchcode {

    my ($self, $params ) = @_;

    my $interface = C4::Context->interface;
    my $branchcode;
    if ( $interface eq 'opac' ){
        my $renewal_branchcode = C4::Context->preference('OpacRenewalBranch');
        if( !defined $renewal_branchcode || $renewal_branchcode eq 'opacrenew' ){
            $branchcode = 'OPACRenew';
        }
        elsif ( $renewal_branchcode eq 'itemhomebranch' ) {
            $branchcode = $self->homebranch;
        }
        elsif ( $renewal_branchcode eq 'patronhomebranch' ) {
            $branchcode = $self->checkout->patron->branchcode;
        }
        elsif ( $renewal_branchcode eq 'checkoutbranch' ) {
            $branchcode = $self->checkout->branchcode;
        }
        else {
            $branchcode = "";
        }
    } else {
        $branchcode = ( C4::Context->userenv && defined C4::Context->userenv->{branch} )
            ? C4::Context->userenv->{branch} : $params->{branch};
    }
    return $branchcode;
}

=head3 cover_images

Return the cover images associated with this item.

=cut

sub cover_images {
    my ( $self ) = @_;

    my $cover_image_rs = $self->_result->cover_images;
    return unless $cover_image_rs;
    return Koha::CoverImages->_new_from_dbic($cover_image_rs);
}

=head3 columns_to_str

    my $values = $items->columns_to_str;

Return a hashref with the string representation of the different attribute of the item.

This is meant to be used for display purpose only.

=cut

sub columns_to_str {
    my ( $self ) = @_;

    my $frameworkcode = $self->biblio->frameworkcode;
    my $tagslib = C4::Biblio::GetMarcStructure(1, $frameworkcode);
    my ( $itemtagfield, $itemtagsubfield) = C4::Biblio::GetMarcFromKohaField( "items.itemnumber" );

    my $columns_info = $self->_result->result_source->columns_info;

    my $mss = C4::Biblio::GetMarcSubfieldStructure( $frameworkcode, { unsafe => 1 } );
    my $values = {};
    for my $column ( keys %$columns_info ) {

        next if $column eq 'more_subfields_xml';

        my $value = $self->$column;
        # Maybe we need to deal with datetime columns here, but so far we have damaged_on, itemlost_on and withdrawn_on, and they are not linked with kohafield

        if ( not defined $value or $value eq "" ) {
            $values->{$column} = $value;
            next;
        }

        my $subfield =
          exists $mss->{"items.$column"}
          ? @{ $mss->{"items.$column"} }[0] # Should we deal with several subfields??
          : undef;

        $values->{$column} =
            $subfield
          ? $subfield->{authorised_value}
              ? C4::Biblio::GetAuthorisedValueDesc( $itemtagfield,
                  $subfield->{tagsubfield}, $value, '', $tagslib )
              : $value
          : $value;
    }

    my $marc_more=
      $self->more_subfields_xml
      ? MARC::Record->new_from_xml( $self->more_subfields_xml, 'UTF-8' )
      : undef;

    my $more_values;
    if ( $marc_more ) {
        my ( $field ) = $marc_more->fields;
        for my $sf ( $field->subfields ) {
            my $subfield_code = $sf->[0];
            my $value = $sf->[1];
            my $subfield = $tagslib->{$itemtagfield}->{$subfield_code};
            next unless $subfield; # We have the value but it's not mapped, data lose! No regression however.
            $value =
              $subfield->{authorised_value}
              ? C4::Biblio::GetAuthorisedValueDesc( $itemtagfield,
                $subfield->{tagsubfield}, $value, '', $tagslib )
              : $value;

            push @{$more_values->{$subfield_code}}, $value;
        }

        while ( my ( $k, $v ) = each %$more_values ) {
            $values->{$k} = join ' | ', @$v;
        }
    }

    return $values;
}

=head3 additional_attributes

    my $attributes = $item->additional_attributes;
    $attributes->{k} = 'new k';
    $item->update({ more_subfields => $attributes->to_marcxml });

Returns a Koha::Item::Attributes object that represents the non-mapped
attributes for this item.

=cut

sub additional_attributes {
    my ($self) = @_;

    return Koha::Item::Attributes->new_from_marcxml(
        $self->more_subfields_xml,
    );
}

=head3 _set_found_trigger

    $self->_set_found_trigger

Finds the most recent lost item charge for this item and refunds the patron
appropriately, taking into account any payments or writeoffs already applied
against the charge.

Internal function, not exported, called only by Koha::Item->store.

=cut

sub _set_found_trigger {
    my ( $self, $pre_mod_item ) = @_;

    ## If item was lost, it has now been found, reverse any list item charges if necessary.
    my $no_refund_after_days =
      C4::Context->preference('NoRefundOnLostReturnedItemsAge');
    if ($no_refund_after_days) {
        my $today = dt_from_string();
        my $lost_age_in_days =
          dt_from_string( $pre_mod_item->itemlost_on )->delta_days($today)
          ->in_units('days');

        return $self unless $lost_age_in_days < $no_refund_after_days;
    }

    my $lostreturn_policy = Koha::CirculationRules->get_lostreturn_policy(
        {
            item          => $self,
            return_branch => C4::Context->userenv
            ? C4::Context->userenv->{'branch'}
            : undef,
        }
      );

    if ( $lostreturn_policy ) {

        # refund charge made for lost book
        my $lost_charge = Koha::Account::Lines->search(
            {
                itemnumber      => $self->itemnumber,
                debit_type_code => 'LOST',
                status          => [ undef, { '<>' => 'FOUND' } ]
            },
            {
                order_by => { -desc => [ 'date', 'accountlines_id' ] },
                rows     => 1
            }
        )->single;

        if ( $lost_charge ) {

            my $patron = $lost_charge->patron;
            if ( $patron ) {

                my $account = $patron->account;
                my $total_to_refund = 0;

                # Use cases
                if ( $lost_charge->amount > $lost_charge->amountoutstanding ) {

                    # some amount has been cancelled. collect the offsets that are not writeoffs
                    # this works because the only way to subtract from this kind of a debt is
                    # using the UI buttons 'Pay' and 'Write off'
                    my $credit_offsets = $lost_charge->debit_offsets(
                        {
                            'credit_id'               => { '!=' => undef },
                            'credit.credit_type_code' => { '!=' => 'Writeoff' }
                        },
                        { join => 'credit' }
                    );

                    $total_to_refund = ( $credit_offsets->count > 0 )
                      ? $credit_offsets->total * -1    # credits are negative on the DB
                      : 0;
                }

                my $credit_total = $lost_charge->amountoutstanding + $total_to_refund;

                my $credit;
                if ( $credit_total > 0 ) {
                    my $branchcode =
                      C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef;
                    $credit = $account->add_credit(
                        {
                            amount      => $credit_total,
                            description => 'Item found ' . $self->itemnumber,
                            type        => 'LOST_FOUND',
                            interface   => C4::Context->interface,
                            library_id  => $branchcode,
                            item_id     => $self->itemnumber,
                            issue_id    => $lost_charge->issue_id
                        }
                    );

                    $credit->apply( { debits => [$lost_charge] } );
                    $self->{_refunded} = 1;
                }

                # Update the account status
                $lost_charge->status('FOUND');
                $lost_charge->store();

                # Reconcile balances if required
                if ( C4::Context->preference('AccountAutoReconcile') ) {
                    $account->reconcile_balance;
                }
            }
        }

        # restore fine for lost book
        if ( $lostreturn_policy eq 'restore' ) {
            my $lost_overdue = Koha::Account::Lines->search(
                {
                    itemnumber      => $self->itemnumber,
                    debit_type_code => 'OVERDUE',
                    status          => 'LOST'
                },
                {
                    order_by => { '-desc' => 'date' },
                    rows     => 1
                }
            )->single;

            if ( $lost_overdue ) {

                my $patron = $lost_overdue->patron;
                if ($patron) {
                    my $account = $patron->account;

                    # Update status of fine
                    $lost_overdue->status('FOUND')->store();

                    # Find related forgive credit
                    my $refund = $lost_overdue->credits(
                        {
                            credit_type_code => 'FORGIVEN',
                            itemnumber       => $self->itemnumber,
                            status           => [ { '!=' => 'VOID' }, undef ]
                        },
                        { order_by => { '-desc' => 'date' }, rows => 1 }
                    )->single;

                    if ( $refund ) {
                        # Revert the forgive credit
                        $refund->void({ interface => 'trigger' });
                        $self->{_restored} = 1;
                    }

                    # Reconcile balances if required
                    if ( C4::Context->preference('AccountAutoReconcile') ) {
                        $account->reconcile_balance;
                    }
                }
            }
        } elsif ( $lostreturn_policy eq 'charge' ) {
            $self->{_charge} = 1;
        }
    }

    return $self;
}

=head3 public_read_list

This method returns the list of publicly readable database fields for both API and UI output purposes

=cut

sub public_read_list {
    return [
        'itemnumber',     'biblionumber',    'homebranch',
        'holdingbranch',  'location',        'collectioncode',
        'itemcallnumber', 'copynumber',      'enumchron',
        'barcode',        'dateaccessioned', 'itemnotes',
        'onloan',         'uri',             'itype',
        'notforloan',     'damaged',         'itemlost',
        'withdrawn',      'restricted'
    ];
}

=head3 to_api

Overloaded to_api method to ensure item-level itypes is adhered to.

=cut

sub to_api {
    my ($self, $params) = @_;

    my $response = $self->SUPER::to_api($params);
    my $overrides = {};

    $overrides->{effective_item_type_id} = $self->effective_itemtype;

    return { %$response, %$overrides };
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Item object
on the API.

=cut

sub to_api_mapping {
    return {
        itemnumber               => 'item_id',
        biblionumber             => 'biblio_id',
        biblioitemnumber         => undef,
        barcode                  => 'external_id',
        dateaccessioned          => 'acquisition_date',
        booksellerid             => 'acquisition_source',
        homebranch               => 'home_library_id',
        price                    => 'purchase_price',
        replacementprice         => 'replacement_price',
        replacementpricedate     => 'replacement_price_date',
        datelastborrowed         => 'last_checkout_date',
        datelastseen             => 'last_seen_date',
        stack                    => undef,
        notforloan               => 'not_for_loan_status',
        damaged                  => 'damaged_status',
        damaged_on               => 'damaged_date',
        itemlost                 => 'lost_status',
        itemlost_on              => 'lost_date',
        withdrawn                => 'withdrawn',
        withdrawn_on             => 'withdrawn_date',
        itemcallnumber           => 'callnumber',
        coded_location_qualifier => 'coded_location_qualifier',
        issues                   => 'checkouts_count',
        renewals                 => 'renewals_count',
        reserves                 => 'holds_count',
        restricted               => 'restricted_status',
        itemnotes                => 'public_notes',
        itemnotes_nonpublic      => 'internal_notes',
        holdingbranch            => 'holding_library_id',
        timestamp                => 'timestamp',
        location                 => 'location',
        permanent_location       => 'permanent_location',
        onloan                   => 'checked_out_date',
        cn_source                => 'call_number_source',
        cn_sort                  => 'call_number_sort',
        ccode                    => 'collection_code',
        materials                => 'materials_notes',
        uri                      => 'uri',
        itype                    => 'item_type_id',
        more_subfields_xml       => 'extended_subfields',
        enumchron                => 'serial_issue_number',
        copynumber               => 'copy_number',
        stocknumber              => 'inventory_number',
        new_status               => 'new_status'
    };
}

=head3 itemtype

    my $itemtype = $item->itemtype;

    Returns Koha object for effective itemtype

=cut

sub itemtype {
    my ( $self ) = @_;
    return Koha::ItemTypes->find( $self->effective_itemtype );
}

=head3 orders

  my $orders = $item->orders();

Returns a Koha::Acquisition::Orders object

=cut

sub orders {
    my ( $self ) = @_;

    my $orders = $self->_result->item_orders;
    return Koha::Acquisition::Orders->_new_from_dbic($orders);
}

=head3 tracked_links

  my $tracked_links = $item->tracked_links();

Returns a Koha::TrackedLinks object

=cut

sub tracked_links {
    my ( $self ) = @_;

    my $tracked_links = $self->_result->linktrackers;
    return Koha::TrackedLinks->_new_from_dbic($tracked_links);
}

=head3 move_to_biblio

  $item->move_to_biblio($to_biblio[, $params]);

Move the item to another biblio and update any references in other tables.

The final optional parameter, C<$params>, is expected to contain the
'skip_record_index' key, which is relayed down to Koha::Item->store.
There it prevents calling index_records, which takes most of the
time in batch adds/deletes. The caller must take care of calling
index_records separately.

$params:
    skip_record_index => 1|0

Returns undef if the move failed or the biblionumber of the destination record otherwise

=cut

sub move_to_biblio {
    my ( $self, $to_biblio, $params ) = @_;

    $params //= {};

    return if $self->biblionumber == $to_biblio->biblionumber;

    my $from_biblionumber = $self->biblionumber;
    my $to_biblionumber = $to_biblio->biblionumber;

    # Own biblionumber and biblioitemnumber
    $self->set({
        biblionumber => $to_biblionumber,
        biblioitemnumber => $to_biblio->biblioitem->biblioitemnumber
    })->store({ skip_record_index => $params->{skip_record_index} });

    unless ($params->{skip_record_index}) {
        my $indexer = Koha::SearchEngine::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
        $indexer->index_records( $from_biblionumber, "specialUpdate", "biblioserver" );
    }

    # Acquisition orders
    $self->orders->update({ biblionumber => $to_biblionumber }, { no_triggers => 1 });

    # Holds
    $self->holds->update({ biblionumber => $to_biblionumber }, { no_triggers => 1 });

    # hold_fill_target (there's no Koha object available yet)
    my $hold_fill_target = $self->_result->hold_fill_target;
    if ($hold_fill_target) {
        $hold_fill_target->update({ biblionumber => $to_biblionumber });
    }

    # tmp_holdsqueues - Can't update with DBIx since the table is missing a primary key
    # and can't even fake one since the significant columns are nullable.
    my $storage = $self->_result->result_source->storage;
    $storage->dbh_do(
        sub {
            my ($storage, $dbh, @cols) = @_;

            $dbh->do("UPDATE tmp_holdsqueue SET biblionumber=? WHERE itemnumber=?", undef, $to_biblionumber, $self->itemnumber);
        }
    );

    # tracked_links
    $self->tracked_links->update({ biblionumber => $to_biblionumber }, { no_triggers => 1 });

    return $to_biblionumber;
}

=head2 Internal methods

=head3 _after_item_action_hooks

Helper method that takes care of calling all plugin hooks

=cut

sub _after_item_action_hooks {
    my ( $self, $params ) = @_;

    my $action = $params->{action};

    Koha::Plugins->call(
        'after_item_action',
        {
            action  => $action,
            item    => $self,
            item_id => $self->itemnumber,
        }
    );
}

=head3 _type

=cut

sub _type {
    return 'Item';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
