use utf8;
package Koha::Schema::Result::Item;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Item

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<items>

=cut

__PACKAGE__->table("items");

=head1 ACCESSORS

=head2 itemnumber

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key and unique identifier added by Koha

=head2 biblionumber

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

foreign key from biblio table used to link this item to the right bib record

=head2 biblioitemnumber

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

foreign key from the biblioitems table to link to item to additional information

=head2 barcode

  data_type: 'varchar'
  is_nullable: 1
  size: 20

item barcode (MARC21 952$p)

=head2 dateaccessioned

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the item was acquired or added to Koha (MARC21 952$d)

=head2 booksellerid

  data_type: 'longtext'
  is_nullable: 1

where the item was purchased (MARC21 952$e)

=head2 homebranch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

foreign key from the branches table for the library that owns this item (MARC21 952$a)

=head2 price

  data_type: 'decimal'
  is_nullable: 1
  size: [8,2]

purchase price (MARC21 952$g)

=head2 replacementprice

  data_type: 'decimal'
  is_nullable: 1
  size: [8,2]

cost the library charges to replace the item if it has been marked lost (MARC21 952$v)

=head2 replacementpricedate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the price is effective from (MARC21 952$w)

=head2 datelastborrowed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the item was last checked out/issued

=head2 datelastseen

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the item was last see (usually the last time the barcode was scanned or inventory was done)

=head2 stack

  data_type: 'tinyint'
  is_nullable: 1

=head2 notforloan

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

authorized value defining why this item is not for loan (MARC21 952$7)

=head2 damaged

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

authorized value defining this item as damaged (MARC21 952$4)

=head2 damaged_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date and time an item was last marked as damaged, NULL if not damaged

=head2 itemlost

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

authorized value defining this item as lost (MARC21 952$1)

=head2 itemlost_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date and time an item was last marked as lost, NULL if not lost

=head2 withdrawn

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

authorized value defining this item as withdrawn (MARC21 952$0)

=head2 withdrawn_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date and time an item was last marked as withdrawn, NULL if not withdrawn

=head2 itemcallnumber

  data_type: 'varchar'
  is_nullable: 1
  size: 255

call number for this item (MARC21 952$o)

=head2 coded_location_qualifier

  data_type: 'varchar'
  is_nullable: 1
  size: 10

coded location qualifier(MARC21 952$f)

=head2 issues

  data_type: 'smallint'
  default_value: 0
  is_nullable: 1

number of times this item has been checked out/issued

=head2 renewals

  data_type: 'smallint'
  is_nullable: 1

number of times this item has been renewed

=head2 reserves

  data_type: 'smallint'
  is_nullable: 1

number of times this item has been placed on hold/reserved

=head2 restricted

  data_type: 'tinyint'
  is_nullable: 1

authorized value defining use restrictions for this item (MARC21 952$5)

=head2 itemnotes

  data_type: 'longtext'
  is_nullable: 1

public notes on this item (MARC21 952$z)

=head2 itemnotes_nonpublic

  data_type: 'longtext'
  is_nullable: 1

non-public notes on this item (MARC21 952$x)

=head2 holdingbranch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

foreign key from the branches table for the library that is currently in possession item (MARC21 952$b)

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

date and time this item was last altered

=head2 location

  data_type: 'varchar'
  is_nullable: 1
  size: 80

authorized value for the shelving location for this item (MARC21 952$c)

=head2 permanent_location

  data_type: 'varchar'
  is_nullable: 1
  size: 80

linked to the CART and PROC temporary locations feature, stores the permanent shelving location

=head2 onloan

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

defines if item is checked out (NULL for not checked out, and due date for checked out)

=head2 cn_source

  data_type: 'varchar'
  is_nullable: 1
  size: 10

classification source used on this item (MARC21 952$2)

=head2 cn_sort

  data_type: 'varchar'
  is_nullable: 1
  size: 255

normalized form of the call number (MARC21 952$o) used for sorting

=head2 ccode

  data_type: 'varchar'
  is_nullable: 1
  size: 80

authorized value for the collection code associated with this item (MARC21 952$8)

=head2 materials

  data_type: 'mediumtext'
  is_nullable: 1

materials specified (MARC21 952$3)

=head2 uri

  data_type: 'mediumtext'
  is_nullable: 1

URL for the item (MARC21 952$u)

=head2 itype

  data_type: 'varchar'
  is_nullable: 1
  size: 10

foreign key from the itemtypes table defining the type for this item (MARC21 952$y)

=head2 more_subfields_xml

  data_type: 'longtext'
  is_nullable: 1

additional 952 subfields in XML format

=head2 enumchron

  data_type: 'mediumtext'
  is_nullable: 1

serial enumeration/chronology for the item (MARC21 952$h)

=head2 copynumber

  data_type: 'varchar'
  is_nullable: 1
  size: 32

copy number (MARC21 952$t)

=head2 stocknumber

  data_type: 'varchar'
  is_nullable: 1
  size: 32

inventory number (MARC21 952$i)

=head2 new_status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

'new' value, you can put whatever free-text information. This field is intented to be managed by the automatic_item_modification_by_age cronjob.

=head2 exclude_from_local_holds_priority

  data_type: 'tinyint'
  is_nullable: 1

Exclude this item from local holds priority

=cut

__PACKAGE__->add_columns(
  "itemnumber",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "biblionumber",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "biblioitemnumber",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "barcode",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "dateaccessioned",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "booksellerid",
  { data_type => "longtext", is_nullable => 1 },
  "homebranch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "price",
  { data_type => "decimal", is_nullable => 1, size => [8, 2] },
  "replacementprice",
  { data_type => "decimal", is_nullable => 1, size => [8, 2] },
  "replacementpricedate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "datelastborrowed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "datelastseen",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "stack",
  { data_type => "tinyint", is_nullable => 1 },
  "notforloan",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "damaged",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "damaged_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "itemlost",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "itemlost_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "withdrawn",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "withdrawn_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "itemcallnumber",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "coded_location_qualifier",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "issues",
  { data_type => "smallint", default_value => 0, is_nullable => 1 },
  "renewals",
  { data_type => "smallint", is_nullable => 1 },
  "reserves",
  { data_type => "smallint", is_nullable => 1 },
  "restricted",
  { data_type => "tinyint", is_nullable => 1 },
  "itemnotes",
  { data_type => "longtext", is_nullable => 1 },
  "itemnotes_nonpublic",
  { data_type => "longtext", is_nullable => 1 },
  "holdingbranch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "location",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "permanent_location",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "onloan",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "cn_source",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "cn_sort",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "ccode",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "materials",
  { data_type => "mediumtext", is_nullable => 1 },
  "uri",
  { data_type => "mediumtext", is_nullable => 1 },
  "itype",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "more_subfields_xml",
  { data_type => "longtext", is_nullable => 1 },
  "enumchron",
  { data_type => "mediumtext", is_nullable => 1 },
  "copynumber",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "stocknumber",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "new_status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "exclude_from_local_holds_priority",
  { data_type => "tinyint", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</itemnumber>

=back

=cut

__PACKAGE__->set_primary_key("itemnumber");

=head1 UNIQUE CONSTRAINTS

=head2 C<itembarcodeidx>

=over 4

=item * L</barcode>

=back

=cut

__PACKAGE__->add_unique_constraint("itembarcodeidx", ["barcode"]);

=head1 RELATIONS

=head2 accountlines

Type: has_many

Related object: L<Koha::Schema::Result::Accountline>

=cut

__PACKAGE__->has_many(
  "accountlines",
  "Koha::Schema::Result::Accountline",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 article_requests

Type: has_many

Related object: L<Koha::Schema::Result::ArticleRequest>

=cut

__PACKAGE__->has_many(
  "article_requests",
  "Koha::Schema::Result::ArticleRequest",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 biblioitemnumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblioitem>

=cut

__PACKAGE__->belongs_to(
  "biblioitemnumber",
  "Koha::Schema::Result::Biblioitem",
  { biblioitemnumber => "biblioitemnumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "biblionumber",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 branchtransfers

Type: has_many

Related object: L<Koha::Schema::Result::Branchtransfer>

=cut

__PACKAGE__->has_many(
  "branchtransfers",
  "Koha::Schema::Result::Branchtransfer",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 club_holds

Type: has_many

Related object: L<Koha::Schema::Result::ClubHold>

=cut

__PACKAGE__->has_many(
  "club_holds",
  "Koha::Schema::Result::ClubHold",
  { "foreign.item_id" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 course_item

Type: might_have

Related object: L<Koha::Schema::Result::CourseItem>

=cut

__PACKAGE__->might_have(
  "course_item",
  "Koha::Schema::Result::CourseItem",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cover_images

Type: has_many

Related object: L<Koha::Schema::Result::CoverImage>

=cut

__PACKAGE__->has_many(
  "cover_images",
  "Koha::Schema::Result::CoverImage",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 creator_batches

Type: has_many

Related object: L<Koha::Schema::Result::CreatorBatch>

=cut

__PACKAGE__->has_many(
  "creator_batches",
  "Koha::Schema::Result::CreatorBatch",
  { "foreign.item_number" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 hold_fill_target

Type: might_have

Related object: L<Koha::Schema::Result::HoldFillTarget>

=cut

__PACKAGE__->might_have(
  "hold_fill_target",
  "Koha::Schema::Result::HoldFillTarget",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 holdingbranch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "holdingbranch",
  "Koha::Schema::Result::Branch",
  { branchcode => "holdingbranch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "CASCADE",
  },
);

=head2 homebranch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "homebranch",
  "Koha::Schema::Result::Branch",
  { branchcode => "homebranch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "CASCADE",
  },
);

=head2 issue

Type: might_have

Related object: L<Koha::Schema::Result::Issue>

=cut

__PACKAGE__->might_have(
  "issue",
  "Koha::Schema::Result::Issue",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 item_bundles_hosts

Type: has_many

Related object: L<Koha::Schema::Result::ItemBundle>

=cut

__PACKAGE__->has_many(
  "item_bundles_hosts",
  "Koha::Schema::Result::ItemBundle",
  { "foreign.host" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 item_bundles_item

Type: might_have

Related object: L<Koha::Schema::Result::ItemBundle>

=cut

__PACKAGE__->might_have(
  "item_bundles_item",
  "Koha::Schema::Result::ItemBundle",
  { "foreign.item" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 items_last_borrower

Type: might_have

Related object: L<Koha::Schema::Result::ItemsLastBorrower>

=cut

__PACKAGE__->might_have(
  "items_last_borrower",
  "Koha::Schema::Result::ItemsLastBorrower",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 linktrackers

Type: has_many

Related object: L<Koha::Schema::Result::Linktracker>

=cut

__PACKAGE__->has_many(
  "linktrackers",
  "Koha::Schema::Result::Linktracker",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 old_issues

Type: has_many

Related object: L<Koha::Schema::Result::OldIssue>

=cut

__PACKAGE__->has_many(
  "old_issues",
  "Koha::Schema::Result::OldIssue",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 old_reserves

Type: has_many

Related object: L<Koha::Schema::Result::OldReserve>

=cut

__PACKAGE__->has_many(
  "old_reserves",
  "Koha::Schema::Result::OldReserve",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 reserves

Type: has_many

Related object: L<Koha::Schema::Result::Reserve>

=cut

__PACKAGE__->has_many(
  "reserves",
  "Koha::Schema::Result::Reserve",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 return_claims

Type: has_many

Related object: L<Koha::Schema::Result::ReturnClaim>

=cut

__PACKAGE__->has_many(
  "return_claims",
  "Koha::Schema::Result::ReturnClaim",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 serialitem

Type: might_have

Related object: L<Koha::Schema::Result::Serialitem>

=cut

__PACKAGE__->might_have(
  "serialitem",
  "Koha::Schema::Result::Serialitem",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 stockrotationitem

Type: might_have

Related object: L<Koha::Schema::Result::Stockrotationitem>

=cut

__PACKAGE__->might_have(
  "stockrotationitem",
  "Koha::Schema::Result::Stockrotationitem",
  { "foreign.itemnumber_id" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tmp_holdsqueues

Type: has_many

Related object: L<Koha::Schema::Result::TmpHoldsqueue>

=cut

__PACKAGE__->has_many(
  "tmp_holdsqueues",
  "Koha::Schema::Result::TmpHoldsqueue",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-08-10 13:47:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zKbxMr6eySAbQsgtVP7kVg

__PACKAGE__->belongs_to( biblioitem => "Koha::Schema::Result::Biblioitem", "biblioitemnumber" );

__PACKAGE__->belongs_to(
  "biblio",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->add_columns(
    '+exclude_from_local_holds_priority' => { is_boolean => 1 },
);

# Relationship with orders via the aqorders_item table that not have foreign keys
__PACKAGE__->has_many(
  "aqorders_item",
  "Koha::Schema::Result::AqordersItem",
  { "foreign.itemnumber" => "self.itemnumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->many_to_many(
  "item_orders",
  "aqorders_item",
  "ordernumber",
);

use C4::Context;
sub effective_itemtype {
    my ( $self ) = @_;

    my $pref = C4::Context->preference('item-level_itypes');
    if ( $pref && $self->itype() ) {
        return $self->itype();
    } else {
        warn "item-level_itypes set but no itemtype set for item (".$self->itemnumber.")"
          if $pref;
        return $self->biblioitemnumber()->itemtype();
    }
}

1;
