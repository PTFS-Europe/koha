package Koha::MarcOrder;

# Copyright 2023, PTFS-Europe Ltd
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
use Try::Tiny qw( catch try );

use base qw(Koha::Object);

use C4::Matcher;
use C4::ImportBatch qw(
    RecordsFromMARCXMLFile
    RecordsFromISO2709File
    RecordsFromMarcPlugin
    BatchStageMarcRecords
    BatchFindDuplicates
    SetImportBatchMatcher
    SetImportBatchOverlayAction
    SetImportBatchNoMatchAction
    SetImportBatchItemAction
    SetImportBatchStatus
    GetImportBatchOverlayAction
    GetImportBatchNoMatchAction
    GetImportBatchItemAction
    GetImportBatch
);
use C4::Search      qw( FindDuplicate );
use C4::Acquisition qw( NewBasket );
use C4::Biblio      qw(
    AddBiblio
    GetMarcFromKohaField
    TransformHtmlToXml
    GetMarcQuantity
);
use C4::Items   qw( AddItemFromMarc );
use C4::Budgets qw( GetBudgetByCode );

use Koha::Database;
use Koha::ImportBatchProfiles;
use Koha::ImportBatches;
use Koha::Import::Records;
use Koha::Acquisition::Currencies;
use Koha::Acquisition::Booksellers;
use Koha::Acquisition::Baskets;
use Koha::Plugins;

=head1 NAME

Koha::MarcOrder - Koha Marc Order Object class

=head1 API

=head2 Class methods

=cut

=head3 create_order_lines_from_file

    my $result = Koha::MarcOrder->create_order_lines_from_file($args);

    Controller for file staging, basket creation and order line creation when using the cronjob in marc_ordering_process.pl
=cut

sub create_order_lines_from_file {
    my ( $self, $args ) = @_;

    my $filename = $args->{filename};
    my $filepath = $args->{filepath};
    my $profile  = $args->{profile};
    my $agent    = $args->{agent};

    my $success;
    my $error;

    my $vendor_id = $profile->vendor_id;
    my $budget_id = $profile->budget_id;

    my $vendor_record = Koha::Acquisition::Booksellers->find( { id => $vendor_id } );

    my $basket_id = _create_basket_for_file(
        {
            filename  => $filename,
            vendor_id => $vendor_id
        }
    );

    my $format = index( $filename, '.mrc' ) != -1 ? 'ISO2709' : 'MARCXML';
    my $params = {
        record_type    => $profile->record_type,
        encoding       => $profile->encoding,
        format         => $format,
        filepath       => $filepath,
        filename       => $filename,
        comments       => undef,
        parse_items    => $profile->parse_items,
        matcher_id     => $profile->matcher_id,
        overlay_action => $profile->overlay_action,
        nomatch_action => $profile->nomatch_action,
        item_action    => $profile->item_action,
    };

    try {
        my $import_batch_id = _stage_file($params);

        my $import_records = Koha::Import::Records->search(
            {
                import_batch_id => $import_batch_id,
            }
        );

        while ( my $import_record = $import_records->next ) {
            my $result = add_biblio_from_import_record(
                {
                    import_batch_id => $import_batch_id,
                    import_record   => $import_record,
                    matcher_id      => $params->{matcher_id},
                    overlay_action  => $params->{overlay_action},
                    agent           => $agent,
                }
            );
            warn "Duplicates found in $result->{duplicates_in_batch}, record was skipped."
                if $result->{duplicates_in_batch};
            next if $result->{skip};

            my $order_line_details = add_items_from_import_record(
                {
                    record_result => $result->{record_result},
                    basket_id     => $basket_id,
                    vendor        => $vendor_record,
                    budget_id     => $budget_id,
                    agent         => $agent,
                }
            );

            my $order_lines = create_order_lines( { order_line_details => $order_line_details } );
        }
        SetImportBatchStatus( $import_batch_id, 'imported' )
            if Koha::Import::Records->search( { import_batch_id => $import_batch_id, status => 'imported' } )->count ==
            Koha::Import::Records->search( { import_batch_id => $import_batch_id } )->count;

        $success = 1;
    } catch {
        $success = 0;
        $error   = $_;
    };

    return $success ? { success => 1, error => '' } : { success => 0, error => $error };
}

=head3 import_record_and_create_order_lines

    my $result = Koha::MarcOrder->import_record_and_create_order_lines($args);

    Controller for record import and order line creation when using the interface in addorderiso2709.pl

=cut

sub import_record_and_create_order_lines {
    my ( $self, $args ) = @_;

    my $import_batch_id           = $args->{import_batch_id};
    my $import_record_id_selected = $args->{import_record_id_selected} || ();
    my $matcher_id                = $args->{matcher_id};
    my $overlay_action            = $args->{overlay_action};
    my $import_record             = $args->{import_record};
    my $client_item_fields        = $args->{client_item_fields};
    my $agent                     = $args->{agent};
    my $basket_id                 = $args->{basket_id};
    my $budget_id                 = $args->{budget_id};
    my $vendor                    = $args->{vendor};

    my $result = add_biblio_from_import_record(
        {
            import_batch_id           => $import_batch_id,
            import_record             => $import_record,
            matcher_id                => $matcher_id,
            overlay_action            => $overlay_action,
            agent                     => $agent,
            import_record_id_selected => $import_record_id_selected,
        }
    );

    return {
        duplicates_in_batch => $result->{duplicates_in_batch},
        skip                => $result->{skip}
    } if $result->{skip};

    my $order_line_details = add_items_from_import_record(
        {
            record_result      => $result->{record_result},
            basket_id          => $basket_id,
            vendor             => $vendor,
            budget_id          => $budget_id,
            agent              => $agent,
            client_item_fields => $client_item_fields
        }
    );

    my $order_lines = create_order_lines( { order_line_details => $order_line_details } );

    return {
        duplicates_in_batch => 0,
        skip                => 0
    };
}


=head3 _create_basket_for_file

    my $basket_id = _create_basket_for_file({
        filename  => $filename,
        vendor_id => $vendor_id
    });

    Creates a basket ready to receive order lines based on the imported file
=cut

sub _create_basket_for_file {
    my ($args) = @_;

    my $filename  = $args->{filename};
    my $vendor_id = $args->{vendor_id};

    # aqbasketname.basketname has a max length of 50 characters so long file names will need to be truncated
    my $basketname = length($filename) > 50 ? substr( $filename, 0, 50 ) : $filename;

    my $basketno = NewBasket(
        $vendor_id, 0, $basketname, q{},
        q{} . q{}
    );

    return $basketno;
}

=head3 _stage_file

    $file->_stage_file($params)
    Stages a file directly using parameters from a marc ordering account and without using the background job
    This function is a mirror of Koha::BackgroundJob::StageMARCForImport->process but with the background job functionality removed

=cut

sub _stage_file {
    my ($args) = @_;

    my $record_type                = $args->{record_type};
    my $encoding                   = $args->{encoding};
    my $format                     = $args->{format};
    my $filepath                   = $args->{filepath};
    my $filename                   = $args->{filename};
    my $marc_modification_template = $args->{marc_modification_template};
    my $comments                   = $args->{comments};
    my $parse_items                = $args->{parse_items};
    my $matcher_id                 = $args->{matcher_id};
    my $overlay_action             = $args->{overlay_action};
    my $nomatch_action             = $args->{nomatch_action};
    my $item_action                = $args->{item_action};

    my @messages;
    my ( $batch_id, $num_valid, $num_items, @import_errors );
    my $num_with_matches = 0;
    my $checked_matches  = 0;
    my $matcher_failed   = 0;
    my $matcher_code     = "";

    my $schema = Koha::Database->new->schema;
    try {
        $schema->storage->txn_begin;

        my ( $errors, $marcrecords );
        if ( $format eq 'MARCXML' ) {
            ( $errors, $marcrecords ) = C4::ImportBatch::RecordsFromMARCXMLFile( $filepath, $encoding );
        } elsif ( $format eq 'ISO2709' ) {
            ( $errors, $marcrecords ) = C4::ImportBatch::RecordsFromISO2709File(
                $filepath, $record_type,
                $encoding
            );
        } else {    # plugin based
            $errors      = [];
            $marcrecords = C4::ImportBatch::RecordsFromMarcPlugin(
                $filepath, $format,
                $encoding
            );
        }

        ( $batch_id, $num_valid, $num_items, @import_errors ) = BatchStageMarcRecords(
            $record_type,                $encoding,
            $marcrecords,                $filename,
            $marc_modification_template, $comments,
            '',                          $parse_items,
            0
        );

        if ($matcher_id) {
            my $matcher = C4::Matcher->fetch($matcher_id);
            if ( defined $matcher ) {
                $checked_matches  = 1;
                $matcher_code     = $matcher->code();
                $num_with_matches = BatchFindDuplicates( $batch_id, $matcher, 10 );
                SetImportBatchMatcher( $batch_id, $matcher_id );
                SetImportBatchOverlayAction( $batch_id, $overlay_action );
                SetImportBatchNoMatchAction( $batch_id, $nomatch_action );
                SetImportBatchItemAction( $batch_id, $item_action );
                $schema->storage->txn_commit;
            } else {
                $matcher_failed = 1;
                $schema->storage->txn_rollback;
            }
        } else {
            $schema->storage->txn_commit;
        }

        return $batch_id;
    }
    catch {
        warn $_;
        $schema->storage->txn_rollback;
        die "Something terrible has happened!"
            if ( $_ =~ /Rollback failed/ );    # TODO Check test: Rollback failed
    };
}


=head3 _get_MarcFieldsToOrder_syspref_data

    my $marc_fields_to_order = _get_MarcFieldsToOrder_syspref_data('MarcFieldsToOrder', $marcrecord, $fields);

    Fetches data from a marc record based on the mappings in the syspref MarcFieldsToOrder using the fields selected in $fields (array).

=cut

sub _get_MarcFieldsToOrder_syspref_data {
    my ( $syspref_name, $record, $field_list ) = @_;
    my $syspref = C4::Context->preference($syspref_name);
    $syspref = "$syspref\n\n";
    my $yaml = eval { YAML::XS::Load( Encode::encode_utf8($syspref) ); };
    if ($@) {
        warn "Unable to parse $syspref syspref : $@";
        return ();
    }
    my $r;
    for my $field_name (@$field_list) {
        next unless exists $yaml->{$field_name};
        my @fields = split /\|/, $yaml->{$field_name};
        for my $field (@fields) {
            my ( $f, $sf ) = split /\$/, $field;
            next unless $f and $sf;
            if ( my $v = $record->subfield( $f, $sf ) ) {
                $r->{$field_name} = $v;
            }
            last if $yaml->{$field};
        }
    }
    return $r;
}

=head3 _get_MarcItemFieldsToOrder_syspref_data

    my $marc_item_fields_to_order = _get_MarcItemFieldsToOrder_syspref_data('MarcItemFieldsToOrder', $marcrecord, $fields);

    Fetches data from a marc record based on the mappings in the syspref MarcItemFieldsToOrder using the fields selected in $fields (array).

=cut

sub _get_MarcItemFieldsToOrder_syspref_data {
    my ($record) = @_;
    my $syspref = C4::Context->preference('MarcItemFieldsToOrder');
    $syspref = "$syspref\n\n";
    my $yaml = eval { YAML::XS::Load( Encode::encode_utf8($syspref) ); };
    if ($@) {
        warn "Unable to parse $syspref syspref : $@";
        return ();
    }
    my @result;
    my @tags_list;

    # Check tags in syspref definition
    for my $field_name ( keys %$yaml ) {
        my @fields = split /\|/, $yaml->{$field_name};
        for my $field (@fields) {
            my ( $f, $sf ) = split /\$/, $field;
            next unless $f and $sf;
            push @tags_list, $f;
        }
    }
    @tags_list = List::MoreUtils::uniq(@tags_list);

    my $tags_count = _verify_number_of_fields( \@tags_list, $record );

    # Return if the number of these fields in the record is not the same.
    die "Invalid number of fields detected on field $tags_count->{key}, please check this file" if $tags_count->{error};

    # Gather the fields
    my $fields_hash;
    foreach my $tag (@tags_list) {
        my @tmp_fields;
        foreach my $field ( $record->field($tag) ) {
            push @tmp_fields, $field;
        }
        $fields_hash->{$tag} = \@tmp_fields;
    }

    if ( $tags_count->{count} ) {
        for ( my $i = 0 ; $i < $tags_count->{count} ; $i++ ) {
            my $r;
            for my $field_name ( keys %$yaml ) {
                my @fields = split /\|/, $yaml->{$field_name};
                for my $field (@fields) {
                    my ( $f, $sf ) = split /\$/, $field;
                    next unless $f and $sf;
                    my $v = $fields_hash->{$f}[$i] ? $fields_hash->{$f}[$i]->subfield($sf) : undef;
                    $r->{$field_name} = $v if ( defined $v );
                    last if $yaml->{$field};
                }
            }
            push @result, $r;
        }
    }

    return $result[0];
}

=head3 _verify_number_of_fields

    my $tags_count = _verify_number_of_fields(\@tags_list, $record);

    Verifies that the number of fields in the record is consistent for each field

=cut

sub _verify_number_of_fields {
    my ( $tags_list, $record ) = @_;
    my $tag_fields_count;
    for my $tag (@$tags_list) {
        my @fields = $record->field($tag);
        $tag_fields_count->{$tag} = scalar @fields;
    }

    my $tags_count;
    foreach my $key ( keys %$tag_fields_count ) {
        if ( $tag_fields_count->{$key} > 0 ) {    # Having 0 of a field is ok
            $tags_count //= $tag_fields_count->{$key};    # Start with the count from the first occurrence
            return { error => 1, key => $key }
                if $tag_fields_count->{$key} !=
                $tags_count;                              # All counts of various fields should be equal if they exist
        }
    }
    return { error => 0, count => $tags_count };
}

=head3 add_biblio_from_import_record

    my ($record_results, $duplicates_in_batch) = add_biblio_from_import_record({
        import_record             => $import_record,
        matcher_id                => $matcher_id,
        overlay_action            => $overlay_action,
        import_record_id_selected => $import_record_id_selected,
        agent                     => $agent,
        import_batch_id           => $import_batch_id
    });

    Takes a set of import records and adds biblio records based on the file content.
    Params matcher_id and overlay_action are taken from the marc ordering account.
    Returns the new or matched biblionumber and the marc record for each import record.

=cut

sub add_biblio_from_import_record {
    my ($args) = @_;

    my $import_batch_id           = $args->{import_batch_id};
    my $import_record_id_selected = $args->{import_record_id_selected} || ();
    my $matcher_id                = $args->{matcher_id};
    my $overlay_action            = $args->{overlay_action};
    my $import_record             = $args->{import_record};
    my $agent                     = $args->{agent} || "";
    my $duplicates_in_batch;

    my $duplicates_found = 0;
    if ( $agent eq 'client' ) {
        return {
            record_result       => 0,
            duplicates_in_batch => 0,
            skip                => 1
        } if not grep { $_ eq $import_record->import_record_id } @{$import_record_id_selected};
    }

    my $marcrecord   = $import_record->get_marc_record || die "Couldn't translate marc information";
    my $matches      = $import_record->get_import_record_matches( { chosen => 1 } );
    my $match        = $matches->count ? $matches->next             : undef;
    my $biblionumber = $match          ? $match->candidate_match_id : 0;

    if ($biblionumber) {
        $import_record->status('imported')->store;
        if ( $overlay_action eq 'replace' ) {
            my $biblio = Koha::Biblios->find($biblionumber);
            $import_record->replace( { biblio => $biblio } );
        }
    } else {
        if ($matcher_id) {
            if ( $matcher_id eq '_TITLE_AUTHOR_' ) {
                my @matches = FindDuplicate($marcrecord);
                $duplicates_found = 1 if @matches;
            } else {
                my $matcher = C4::Matcher->fetch($matcher_id);
                my @matches = $matcher->get_matches( $marcrecord, my $max_matches = 1 );
                $duplicates_found = 1 if @matches;
            }
            return {
                record_result       => 0,
                duplicates_in_batch => $import_batch_id,
                skip                => 1
            } if $duplicates_found;
        }

        # add the biblio if no matches were found
        if ( !$duplicates_found ) {
            ( $biblionumber, undef ) = AddBiblio( $marcrecord, '' );
            $import_record->status('imported')->store;
        }
    }
    $import_record->import_biblio->matched_biblionumber($biblionumber)->store;

    my $record_result = {
        biblionumber     => $biblionumber,
        marcrecord       => $marcrecord,
        import_record_id => $import_record->import_record_id,
    };

    return {
        record_result       => $record_result,
        duplicates_in_batch => $duplicates_in_batch,
        skip                => 0
    };
}

=head3 add_items_from_import_record

    my $order_line_details = add_items_from_import_record({
        record_result      => $record_result,
        basket_id          => $basket_id,
        vendor             => $vendor,
        budget_id          => $budget_id,
        agent              => $agent,
        client_item_fields => $client_item_fields
    });

    Adds items to biblio records based on mappings in MarcItemFieldsToOrder.
    Returns an array of order line details based on newly added items.
    If being called from addorderiso2709.pl then client_item_fields is a hash of all the UI form inputs needed by the script.

=cut

sub add_items_from_import_record {
    my ($args) = @_;

    my $record_result      = $args->{record_result};
    my $basket_id          = $args->{basket_id};
    my $budget_id          = $args->{budget_id};
    my $vendor             = $args->{vendor};
    my $agent              = $args->{agent};
    my $client_item_fields = $args->{client_item_fields} || undef;
    my $active_currency    = Koha::Acquisition::Currencies->get_active;
    my $biblionumber       = $record_result->{biblionumber};
    my $marcrecord         = $record_result->{marcrecord};

    if ( $agent eq 'cron' ) {
        my $marc_fields_to_order = _get_MarcFieldsToOrder_syspref_data(
            'MarcFieldsToOrder', $marcrecord,
            [ 'price', 'quantity', 'budget_code', 'discount', 'sort1', 'sort2' ]
        );

        my $marc_item_fields_to_order = _get_MarcItemFieldsToOrder_syspref_data($marcrecord);

        my $item_fields = {
            homebranch               => $marc_item_fields_to_order->{homebranch},
            holdingbranch            => $marc_item_fields_to_order->{holdingbranch},
            itype                    => $marc_item_fields_to_order->{itype},
            nonpublic_note           => $marc_item_fields_to_order->{nonpublic_note},
            public_note              => $marc_item_fields_to_order->{public_note},
            loc                      => $marc_item_fields_to_order->{loc},
            ccode                    => $marc_item_fields_to_order->{ccode},
            notforloan               => $marc_item_fields_to_order->{notforloan},
            uri                      => $marc_item_fields_to_order->{uri},
            copyno                   => $marc_item_fields_to_order->{copyno},
            quantity                 => $marc_item_fields_to_order->{quantity},
            price                    => $marc_item_fields_to_order->{price},
            replacementprice         => $marc_item_fields_to_order->{replacementprice},
            itemcallnumber           => $marc_item_fields_to_order->{itemcallnumber},
            coded_location_qualifier => $marc_item_fields_to_order->{coded_location_qualifier},
            barcode                  => $marc_item_fields_to_order->{barcode},
            enumchron                => $marc_item_fields_to_order->{enumchron},
            budget_code              => $marc_item_fields_to_order->{budget_code},
            c_quantity               => $marc_fields_to_order->{quantity},
            c_budget_code            => $marc_fields_to_order->{budget_code},
            c_price                  => $marc_fields_to_order->{price},
            c_discount               => $marc_fields_to_order->{discount},
            c_sort1                  => $marc_fields_to_order->{sort1},
            c_sort2                  => $marc_fields_to_order->{sort2},
        };

        my $order_line_fields = parse_input_into_order_line_fields(
            {
                agent        => $agent,
                biblionumber => $biblionumber,
                budget_id    => $budget_id,
                basket_id    => $basket_id,
                fields       => $item_fields,
            }
        );

        my $order_line_details = create_items_and_generate_order_hash(
            {
                fields          => $order_line_fields,
                vendor          => $vendor,
                agent           => $agent,
                active_currency => $active_currency,
                marcfields      => $marc_fields_to_order,
                marcrecord      => $marcrecord,
            }
        );

        return $order_line_details;
    }

    if ( $agent eq 'client' ) {
        my $order_line_fields = parse_input_into_order_line_fields(
            {
                agent        => $agent,
                biblionumber => $biblionumber,
                budget_id    => $budget_id,
                basket_id    => $basket_id,
                fields       => $client_item_fields,
            }
        );

        my $order_line_details = create_items_and_generate_order_hash(
            {
                fields          => $order_line_fields,
                vendor          => $vendor,
                agent           => $agent,
                active_currency => $active_currency,
            }
        );

        return $order_line_details;
    }

    # return \@order_line_details;
}

=head3 create_items_and_generate_order_hash

    my $order_lines = create_order_lines({
        order_line_details => $order_line_details
    });

    Creates order lines based on an array of order line details

=cut

sub create_order_lines {
    my ($args) = @_;

    my $order_line_details = $args->{order_line_details};

    foreach my $order_detail ( @{$order_line_details} ) {
        my @itemnumbers = $order_detail->{itemnumbers} || ();
        delete( $order_detail->{itemnumbers} );
        my $order = Koha::Acquisition::Order->new( \%{$order_detail} );
        $order->populate_with_prices_for_ordering();
        $order->populate_with_prices_for_receiving();
        $order->store;
        foreach my $itemnumber (@itemnumbers) {
            $order->add_item($itemnumber);
        }
    }
    return;
}


=head3 match_file_to_account

    my $file_match = Koha::MarcOrder->match_file_to_account({
        filename => $filename,
        filepath => $filepath,
        profile  => $profile
    });

    Used by the cronjob to detect whether a file matches the account and should be processed

=cut


sub match_file_to_account {
    my ($self, $args) = @_;

    my $match       = 0;
    my $filename    = $args->{filename};
    my $filepath    = $args->{filepath};
    my $profile     = $args->{profile};
    my $format      = index($filename, '.mrc') != -1 ? 'ISO2709' : 'MARCXML';

    my ( $errors, $marcrecords );
    if ( $format eq 'MARCXML' ) {
        ( $errors, $marcrecords ) = C4::ImportBatch::RecordsFromMARCXMLFile( $filepath, $profile->encoding );
    } elsif ( $format eq 'ISO2709' ) {
        ( $errors, $marcrecords ) = C4::ImportBatch::RecordsFromISO2709File(
            $filepath, $profile->record_type,
            $profile->encoding
        );
    }

    my $match_record = @{ $marcrecords }[0];
    my ( $field, $subfield ) = split /\$/, $profile->match_field;

    my $field_value = $match_record->subfield( $field, $subfield );
    my $match_value = $profile->match_value;

    if($field_value eq $match_value) {
        $match = 1;
    }

    return $match;
}


=head3 import_batches_list

Fetches import batches matching the batch to be added to the basket and returns these to the template

Koha::MarcOrder->import_batches_list();

=cut

sub import_batches_list {
    my ($self) = @_;
    my $batches = GetImportBatchRangeDesc();

    my @list = ();
    foreach my $batch (@$batches) {
        if ( $batch->{'import_status'} =~ /^staged$|^reverted$/ && $batch->{'record_type'} eq 'biblio' ) {

            # check if there is at least 1 line still staged
            my $import_records_count = Koha::Import::Records->search(
                {
                    import_batch_id => $batch->{'import_batch_id'},
                    status          => $batch->{import_status}
                }
            )->count;
            if ($import_records_count) {
                push @list, {
                    import_batch_id => $batch->{'import_batch_id'},
                    num_records     => $batch->{'num_records'},
                    num_items       => $batch->{'num_items'},
                    staged_date     => $batch->{'upload_timestamp'},
                    import_status   => $batch->{'import_status'},
                    file_name       => $batch->{'file_name'},
                    comments        => $batch->{'comments'},
                };
            } else {

                # if there are no more line to includes, set the status to imported
                # FIXME This should be removed in the future.
                SetImportBatchStatus( $batch->{'import_batch_id'}, 'imported' );
            }
        }
    }
    my $num_batches = GetNumberOfNonZ3950ImportBatches();

    return {
        list        => \@list,
        num_results => $num_batches
    };
}

=head3

For an import batch, this function reads the files and creates all the relevant data pertaining to that file
It then returns this to the template to be shown in the UI

Koha::MarcOrder->import_biblios_list( $cgiparams->{'import_batch_id'} );

=cut

sub import_biblios_list {
    my ( $self, $import_batch_id ) = @_;
    my $batch = GetImportBatch( $import_batch_id, 'staged' );
    return () unless $batch and $batch->{import_status} =~ /^staged$|^reverted$/;
    my $import_records = Koha::Import::Records->search(
        {
            import_batch_id => $import_batch_id,
            status          => $batch->{import_status}
        }
    );
    my @list       = ();
    my $item_error = 0;

    my $ccodes = {
        map { $_->{authorised_value} => $_->{opac_description} }
            Koha::AuthorisedValues->get_descriptions_by_koha_field(
            { frameworkcode => '', kohafield => 'items.ccode' }
            )
    };
    my $locations = {
        map { $_->{authorised_value} => $_->{opac_description} }
            Koha::AuthorisedValues->get_descriptions_by_koha_field(
            { frameworkcode => '', kohafield => 'items.location' }
            )
    };
    my $notforloans = {
        map { $_->{authorised_value} => $_->{lib} } Koha::AuthorisedValues->get_descriptions_by_koha_field(
            { frameworkcode => '', kohafield => 'items.notforloan' }
        )
    };

    # location list
    my @locations;
    foreach ( sort keys %$locations ) {
        push @locations, { code => $_, description => "$_ - " . $locations->{$_} };
    }
    my @ccodes;
    foreach ( sort { $ccodes->{$a} cmp $ccodes->{$b} } keys %$ccodes ) {
        push @ccodes, { code => $_, description => $ccodes->{$_} };
    }
    my @notforloans;
    foreach ( sort { $notforloans->{$a} cmp $notforloans->{$b} } keys %$notforloans ) {
        push @notforloans, { code => $_, description => $notforloans->{$_} };
    }

    my $biblio_count = 0;
    while ( my $import_record = $import_records->next ) {
        my $item_id = 1;
        $biblio_count++;
        my $matches      = $import_record->get_import_record_matches( { chosen => 1 } );
        my $match        = $matches->count ? $matches->next                                               : undef;
        my $match_biblio = $match ? Koha::Biblios->find( { biblionumber => $match->candidate_match_id } ) : undef;
        my %cellrecord   = (
            import_record_id   => $import_record->import_record_id,
            import_biblio      => $import_record->import_biblio,
            import             => 1,
            status             => $import_record->status,
            record_sequence    => $import_record->record_sequence,
            overlay_status     => $import_record->overlay_status,
            match_biblionumber => $match ? $match->candidate_match_id : 0,
            match_citation     => $match_biblio
            ? ( $match_biblio->title || '' ) . ' ' . ( $match_biblio->author || '' )
            : '',
            match_score => $match ? $match->score : 0,
        );
        my $marcrecord = $import_record->get_marc_record || die "couldn't translate marc information";

        my $infos = _get_MarcFieldsToOrder_syspref_data(
            'MarcFieldsToOrder', $marcrecord,
            [ 'price', 'quantity', 'budget_code', 'discount', 'sort1', 'sort2', 'replacementprice' ]
        );
        my $price            = $infos->{price};
        my $replacementprice = $infos->{replacementprice};
        my $quantity         = $infos->{quantity};
        my $budget_code      = $infos->{budget_code};
        my $discount         = $infos->{discount};
        my $sort1            = $infos->{sort1};
        my $sort2            = $infos->{sort2};
        my $budget_id;

        if ($budget_code) {
            my $biblio_budget = GetBudgetByCode($budget_code);
            if ($biblio_budget) {
                $budget_id = $biblio_budget->{budget_id};
            }
        }

        # Items
        my @itemlist           = ();
        my $all_items_quantity = 0;
        my $alliteminfos       = _get_MarcItemFieldsToOrder_syspref_data($marcrecord);
        if ( !$alliteminfos || %$alliteminfos != -1 ) {

            # Quantity is required, default to one if not supplied
            my $quantity = delete $alliteminfos->{quantity} || 1;

            # Handle incorrectly named original parameters for MarcItemFieldsToOrder
            $alliteminfos->{location}   = delete $alliteminfos->{loc}    if $alliteminfos->{loc};
            $alliteminfos->{copynumber} = delete $alliteminfos->{copyno} if $alliteminfos->{copyno};

            # Convert budget code to a budget id
            my $item_budget_code = delete $alliteminfos->{budget_code};
            if ($item_budget_code) {
                my $item_budget = GetBudgetByCode($item_budget_code);
                $alliteminfos->{budget_id} = $item_budget->{budget_id} || $budget_id;
            }

            # Clone the item data for the needed quantity
            # Add the incremented item id for each item in that quantity
            for ( my $i = 0 ; $i < $quantity ; $i++ ) {
                my $itemrecord = {%$alliteminfos};
                $itemrecord->{item_id} = $item_id++;

                # Rename price field to match UI
                $itemrecord->{itemprice} = delete $itemrecord->{price} if $itemrecord->{price};
                $all_items_quantity++;
                push @itemlist, $itemrecord;
            }

            $cellrecord{'iteminfos'} = \@itemlist;
        } else {
            $cellrecord{'item_error'} = 1;
        }
        push @list, \%cellrecord;

        # If MarcItemFieldsToOrder is not set, we use MarcFieldsToOrder to populate the order form.
        if ( $alliteminfos || %$alliteminfos == -1 ) {
            $cellrecord{price}            = $price            || '';
            $cellrecord{replacementprice} = $replacementprice || '';
            $cellrecord{quantity}         = $quantity         || '';
            $cellrecord{budget_id}        = $budget_id        || '';
        } else {

            # When using MarcItemFields to order we want the order to have the same quantity as total items
            $cellrecord{quantity} = $all_items_quantity;
        }

        # The fields discount, sort1, and sort2 only exist at the order level, so always use MarcItemFieldsToOrder
        $cellrecord{discount} = $discount || '';
        $cellrecord{sort1}    = $sort1    || '';
        $cellrecord{sort2}    = $sort2    || '';

    }
    my $num_records    = $batch->{'num_records'};
    my $overlay_action = GetImportBatchOverlayAction($import_batch_id);
    my $nomatch_action = GetImportBatchNoMatchAction($import_batch_id);
    my $item_action    = GetImportBatchItemAction($import_batch_id);
    my $result         = {
        import_biblio_list => \@list,
        num_results        => $num_records,
        import_batch_id    => $import_batch_id,
        overlay_action     => $overlay_action,
        nomatch_action     => $nomatch_action,
        item_action        => $item_action,
        item_error         => $item_error,
        locationloop       => \@locations,
        ccodeloop          => \@ccodes,
        notforloanloop     => \@notforloans,
        batch              => $batch,
    };

    if ( $batch->{'num_records'} > 0 ) {
        if ( $batch->{'import_status'} eq 'staged' or $batch->{'import_status'} eq 'reverted' ) {
            $result->{can_commit} = 1;
        }
        if ( $batch->{'import_status'} eq 'imported' ) {
            $result->{can_revert} = 1;
        }
    }
    if ( defined $batch->{'matcher_id'} ) {
        my $matcher = C4::Matcher->fetch( $batch->{'matcher_id'} );
        if ( defined $matcher ) {
            $result->{'current_matcher_id'}          = $batch->{'matcher_id'};
            $result->{'current_matcher_code'}        = $matcher->code();
            $result->{'current_matcher_description'} = $matcher->description();
        }
    }

    my @matchers = C4::Matcher::GetMatcherList();
    if ( defined $batch->{'matcher_id'} ) {
        for ( my $i = 0 ; $i <= $#matchers ; $i++ ) {
            if ( $matchers[$i]->{'matcher_id'} == $batch->{'matcher_id'} ) {
                $matchers[$i]->{'selected'} = 1;
            }
        }
    }
    $result->{available_matchers} = \@matchers;

    return $result;
}

=head3 parse_input_into_order_line_fields

This function takes inputs from either the cronjob or UI and then parses that into a single set of order line fields that can be used to create items and order lines

my $order_line_fields = parse_input_into_order_line_fields(
    {
        agent        => $agent,
        biblionumber => $biblionumber,
        budget_id    => $budget_id,
        basket_id    => $basket_id,
        fields       => $item_fields,
    }
);


=cut

sub parse_input_into_order_line_fields {
    my ($args) = @_;

    my $agent        = $args->{agent};
    my $client       = $agent eq 'client' ? 1 : 0;
    my $biblionumber = $args->{biblionumber};
    my $budget_id    = $args->{budget_id};
    my $basket_id    = $args->{basket_id};
    my $fields       = $args->{fields};

    my $quantity        = $fields->{quantity} || 1;
    my @homebranches    = $client ? @{ $fields->{homebranches} }    : ( ( $fields->{homebranch} ) x $quantity );
    my @holdingbranches = $client ? @{ $fields->{holdingbranches} } : ( ( $fields->{holdingbranch} ) x $quantity );
    my @itypes          = $client ? @{ $fields->{itypes} }          : ( ( $fields->{itype} ) x $quantity );
    my @nonpublic_notes = $client ? @{ $fields->{nonpublic_notes} } : ( ( $fields->{nonpublic_note} ) x $quantity );
    my @public_notes    = $client ? @{ $fields->{public_notes} }    : ( ( $fields->{public_note} ) x $quantity );
    my @locs            = $client ? @{ $fields->{locs} }            : ( ( $fields->{loc} ) x $quantity );
    my @ccodes          = $client ? @{ $fields->{ccodes} }          : ( ( $fields->{ccode} ) x $quantity );
    my @notforloans     = $client ? @{ $fields->{notforloans} }     : ( ( $fields->{notforloan} ) x $quantity );
    my @uris            = $client ? @{ $fields->{uris} }            : ( ( $fields->{uri} ) x $quantity );
    my @copynos         = $client ? @{ $fields->{copynos} }         : ( ( $fields->{copyno} ) x $quantity );
    my @itemprices      = $client ? @{ $fields->{itemprices} }      : ( ( $fields->{price} ) x $quantity );
    my @replacementprices =
        $client ? @{ $fields->{replacementprices} } : ( ( $fields->{replacementprice} ) x $quantity );
    my @itemcallnumbers = $client ? @{ $fields->{itemcallnumbers} } : ( ( $fields->{itemcallnumber} ) x $quantity );
    my @coded_location_qualifiers =
        $client ? @{ $fields->{coded_location_qualifiers} } : ( ( $fields->{coded_location_qualifier} ) x $quantity );
    my @barcodes            = $client ? @{ $fields->{barcodes} }       : ( ( $fields->{barcode} ) x $quantity );
    my @enumchrons          = $client ? @{ $fields->{enumchrons} }     : ( ( $fields->{enumchron} ) x $quantity );
    my $c_quantity          = $client ? $fields->{c_quantity}          : $fields->{c_quantity};
    my $c_budget_id         = $client ? $fields->{c_budget_id}         : $fields->{c_budget_id};
    my $c_discount          = $client ? $fields->{c_discount}          : $fields->{c_discount};
    my $c_sort1             = $client ? $fields->{c_sort1}             : $fields->{c_sort1};
    my $c_sort2             = $client ? $fields->{c_sort2}             : $fields->{c_sort2};
    my $c_replacement_price = $client ? $fields->{c_replacement_price} : $fields->{c_replacement_price};
    my $c_price             = $client ? $fields->{c_price}             : $fields->{c_price};

    # If using the cronjob, we want to default to the account budget if not mapped on the record
    my $item_budget_id;
    if ( !$client && ( $fields->{budget_code} || $fields->{c_budget_code} ) ) {
        my $budget_code = $fields->{budget_code} || $fields->{c_budget_code};
        my $item_budget = GetBudgetByCode($budget_code);
        if ($item_budget) {
            $item_budget_id = $item_budget->{budget_id};
        } else {
            $item_budget_id = $budget_id;
        }
    } else {
        $item_budget_id = $budget_id;
    }
    my @budget_codes = $client ? @{ $fields->{budget_codes} } : ($item_budget_id);
    my $loop_limit   = $client ? scalar(@homebranches)        : $quantity;

    my $order_line_fields = {
        biblionumber             => $biblionumber,
        homebranch               => \@homebranches,
        holdingbranch            => \@holdingbranches,
        itemnotes_nonpublic      => \@nonpublic_notes,
        itemnotes                => \@public_notes,
        location                 => \@locs,
        ccode                    => \@ccodes,
        itype                    => \@itypes,
        notforloan               => \@notforloans,
        uri                      => \@uris,
        copynumber               => \@copynos,
        price                    => \@itemprices,
        replacementprice         => \@replacementprices,
        itemcallnumber           => \@itemcallnumbers,
        coded_location_qualifier => \@coded_location_qualifiers,
        barcode                  => \@barcodes,
        enumchron                => \@enumchrons,
        budget_code              => \@budget_codes,
        loop_limit               => $loop_limit,
        basket_id                => $basket_id,
        budget_id                => $budget_id,
        c_quantity               => $c_quantity,
        c_budget_id              => $c_budget_id,
        c_discount               => $c_discount,
        c_sort1                  => $c_sort1,
        c_sort2                  => $c_sort2,
        c_replacement_price      => $c_replacement_price,
        c_price                  => $c_price,
    };

    return $order_line_fields;
}

=head3 create_items_and_generate_order_hash

This method is used from both the cronjob and the UI to create items and generate order line details for those new items

my $order_line_details = create_items_and_generate_order_hash(
    {
        fields          => $order_line_fields,
        vendor          => $vendor,
        agent           => $agent,
        active_currency => $active_currency,
    }
);

=cut

sub create_items_and_generate_order_hash {
    my ($args) = @_;

    my $agent           = $args->{agent};
    my $fields          = $args->{fields};
    my $loop_limit      = $fields->{loop_limit};
    my $basket_id       = $fields->{basket_id};
    my $budget_id       = $fields->{budget_id};
    my $vendor          = $args->{vendor};
    my $marcfields      = $args->{marcfields};
    my $marcrecord      = $args->{marcrecord};
    my $active_currency = $args->{active_currency};
    my @order_line_details;
    my $itemcreation = 0;

    for ( my $i = 0 ; $i < $loop_limit ; $i++ ) {
        $itemcreation = 1;
        my $item = Koha::Item->new(
            {
                biblionumber             => $fields->{biblionumber},
                homebranch               => @{ $fields->{homebranch} }[$i],
                holdingbranch            => @{ $fields->{holdingbranch} }[$i],
                itemnotes_nonpublic      => @{ $fields->{itemnotes_nonpublic} }[$i],
                itemnotes                => @{ $fields->{itemnotes} }[$i],
                location                 => @{ $fields->{location} }[$i],
                ccode                    => @{ $fields->{ccode} }[$i],
                itype                    => @{ $fields->{itype} }[$i],
                notforloan               => @{ $fields->{notforloan} }[$i],
                uri                      => @{ $fields->{uri} }[$i],
                copynumber               => @{ $fields->{copynumber} }[$i],
                price                    => @{ $fields->{price} }[$i],
                replacementprice         => @{ $fields->{replacementprice} }[$i],
                itemcallnumber           => @{ $fields->{itemcallnumber} }[$i],
                coded_location_qualifier => @{ $fields->{coded_location_qualifier} }[$i],
                barcode                  => @{ $fields->{barcode} }[$i],
                enumchron                => @{ $fields->{enumchron} }[$i],
            }
        )->store;

        my %order_detail_hash = (
            biblionumber => $fields->{biblionumber},
            itemnumbers  => ( $item->itemnumber ),
            basketno     => $basket_id,
            quantity     => 1,
            budget_id    => @{ $fields->{budget_code} }[$i]
                || $budget_id,
            currency => $vendor->listprice,
        );

        if ( @{ $fields->{price} }[$i] ) {
            $order_detail_hash{tax_rate_on_ordering}  = $vendor->tax_rate;
            $order_detail_hash{tax_rate_on_receiving} = $vendor->tax_rate;
            my $order_discount = $fields->{c_discount} ? $fields->{c_discount} : $vendor->discount;
            $order_detail_hash{discount} = $order_discount;
            $order_detail_hash{rrp}      = @{ $fields->{price} }[$i];
            $order_detail_hash{ecost} =
                $order_discount ? @{ $fields->{price} }[$i] * ( 1 - $order_discount / 100 ) : @{ $fields->{price} }[$i];
            $order_detail_hash{listprice} = $order_detail_hash{rrp} / $active_currency->rate;
            $order_detail_hash{unitprice} = $order_detail_hash{ecost};
        } else {
            $order_detail_hash{listprice} = 0;
        }
        $order_detail_hash{replacementprice} = @{ $fields->{replacementprice} }[$i] || 0;
        $order_detail_hash{uncertainprice}   = 0 if $order_detail_hash{listprice};

        Koha::Plugins->call(
            'before_orderline_create',
            {
                marcrecord => $marcrecord,
                orderline  => \%order_detail_hash,
                marcfields => $marcfields
            }
        );

        push @order_line_details, \%order_detail_hash;

    }
    return \@order_line_details;
}

1;
