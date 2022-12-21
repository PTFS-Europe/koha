use utf8;
package Koha::Schema::Result::Reserve;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Reserve

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reserves>

=cut

__PACKAGE__->table("reserves");

=head1 ACCESSORS

=head2 reserve_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 borrowernumber

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

foreign key from the borrowers table defining which patron this hold is for

=head2 reservedate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the hold was placed

=head2 biblionumber

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

foreign key from the biblio table defining which bib record this hold is on

=head2 branchcode

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 10

foreign key from the branches table defining which branch the patron wishes to pick this hold up at

=head2 desk_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key from the desks table defining which desk the patron should pick this hold up at

=head2 notificationdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

currently unused

=head2 reminderdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

currently unused

=head2 cancellationdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date this hold was cancelled

=head2 cancellation_reason

  data_type: 'varchar'
  is_nullable: 1
  size: 80

optional authorised value CANCELLATION_REASON

=head2 reservenotes

  data_type: 'longtext'
  is_nullable: 1

notes related to this hold

=head2 priority

  data_type: 'smallint'
  default_value: 1
  is_nullable: 0

where in the queue the patron sits

=head2 found

  data_type: 'varchar'
  is_nullable: 1
  size: 1

a one letter code defining what the status is of the hold is after it has been confirmed

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

the date and time this hold was last updated

=head2 itemnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key from the items table defining the specific item the patron has placed on hold or the item this hold was filled with

=head2 waitingdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the item was marked as waiting for the patron at the library

=head2 expirationdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

the date the hold expires (usually the date entered by the patron to say they don't need the hold after a certain date)

=head2 lowestPriority

  accessor: 'lowest_priority'
  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 suspend

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 suspend_until

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 itemtype

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

If record level hold, the optional itemtype of the item the patron is requesting

=head2 item_level_hold

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Is the hpld placed at item level

=head2 non_priority

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Is this a non priority hold

=cut

__PACKAGE__->add_columns(
  "reserve_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "borrowernumber",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "reservedate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "biblionumber",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "branchcode",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 10 },
  "desk_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "notificationdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "reminderdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "cancellationdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "cancellation_reason",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "reservenotes",
  { data_type => "longtext", is_nullable => 1 },
  "priority",
  { data_type => "smallint", default_value => 1, is_nullable => 0 },
  "found",
  { data_type => "varchar", is_nullable => 1, size => 1 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "itemnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "waitingdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "expirationdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "lowestPriority",
  {
    accessor      => "lowest_priority",
    data_type     => "tinyint",
    default_value => 0,
    is_nullable   => 0,
  },
  "suspend",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "suspend_until",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "itemtype",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "item_level_hold",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "non_priority",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</reserve_id>

=back

=cut

__PACKAGE__->set_primary_key("reserve_id");

=head1 RELATIONS

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

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 branchcode

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "branchcode",
  "Koha::Schema::Result::Branch",
  { branchcode => "branchcode" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 club_holds_to_patron_holds

Type: has_many

Related object: L<Koha::Schema::Result::ClubHoldsToPatronHold>

=cut

__PACKAGE__->has_many(
  "club_holds_to_patron_holds",
  "Koha::Schema::Result::ClubHoldsToPatronHold",
  { "foreign.hold_id" => "self.reserve_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 desk

Type: belongs_to

Related object: L<Koha::Schema::Result::Desk>

=cut

__PACKAGE__->belongs_to(
  "desk",
  "Koha::Schema::Result::Desk",
  { desk_id => "desk_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 itemnumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Item>

=cut

__PACKAGE__->belongs_to(
  "itemnumber",
  "Koha::Schema::Result::Item",
  { itemnumber => "itemnumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 itemtype

Type: belongs_to

Related object: L<Koha::Schema::Result::Itemtype>

=cut

__PACKAGE__->belongs_to(
  "itemtype",
  "Koha::Schema::Result::Itemtype",
  { itemtype => "itemtype" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-09-14 09:34:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jvSp6ba0qGenaEBt4HEDww

__PACKAGE__->belongs_to(
  "item",
  "Koha::Schema::Result::Item",
  { itemnumber => "itemnumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

__PACKAGE__->belongs_to(
  "biblio",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

__PACKAGE__->belongs_to(
  "patron",
  "Koha::Schema::Result::Borrower",
  { "foreign.borrowernumber" => "self.borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

__PACKAGE__->add_columns(
    '+item_level_hold' => { is_boolean => 1 },
    '+lowestPriority'  => { is_boolean => 1 },
    '+suspend'         => { is_boolean => 1 },
    '+non_priority'    => { is_boolean => 1 }
);

sub koha_object_class {
    'Koha::Hold';
}
sub koha_objects_class {
    'Koha::Holds';
}

__PACKAGE__->belongs_to(
  "itembib",
  "Koha::Schema::Result::Item",
  { biblionumber => "biblionumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

1;
