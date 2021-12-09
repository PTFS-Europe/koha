use utf8;
package Koha::Schema::Result::OldIssue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OldIssue

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<old_issues>

=cut

__PACKAGE__->table("old_issues");

=head1 ACCESSORS

=head2 issue_id

  data_type: 'integer'
  is_nullable: 0

primary key for issues table

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key, linking this to the borrowers table for the patron this item was checked out to

=head2 issuer_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key, linking this to the borrowers table for the user who checked out this item

=head2 itemnumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key, linking this to the items table for the item that was checked out

=head2 date_due

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the item is due (yyyy-mm-dd)

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

foreign key, linking to the branches table for the location the item was checked out

=head2 returndate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the item was returned

=head2 lastreneweddate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the item was last renewed

=head2 renewals

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

lists the number of times the item was renewed

=head2 unseen_renewals

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

lists the number of consecutive times the item was renewed without being seen

=head2 auto_renew

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

automatic renewal

=head2 auto_renew_error

  data_type: 'varchar'
  is_nullable: 1
  size: 32

automatic renewal error

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

the date and time this record was last touched

=head2 issuedate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the item was checked out or issued

=head2 onsite_checkout

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

in house use flag

=head2 note

  data_type: 'longtext'
  is_nullable: 1

issue note text

=head2 notedate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

datetime of issue note (yyyy-mm-dd hh:mm::ss)

=head2 noteseen

  data_type: 'integer'
  is_nullable: 1

describes whether checkout note has been seen 1, not been seen 0 or doesn't exist null

=cut

__PACKAGE__->add_columns(
  "issue_id",
  { data_type => "integer", is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "issuer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "itemnumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "date_due",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "branchcode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "returndate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "lastreneweddate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "renewals",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "unseen_renewals",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "auto_renew",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "auto_renew_error",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "issuedate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "onsite_checkout",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "note",
  { data_type => "longtext", is_nullable => 1 },
  "notedate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "noteseen",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</issue_id>

=back

=cut

__PACKAGE__->set_primary_key("issue_id");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);

=head2 issuer

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "issuer",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "issuer_id" },
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
    on_delete     => "SET NULL",
    on_update     => "SET NULL",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2021-01-21 13:39:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BWwXBAuls9a0HhscR0WlGQ

__PACKAGE__->add_columns(
    '+auto_renew'      => { is_boolean => 1 },
    '+onsite_checkout' => { is_boolean => 1 }
);

__PACKAGE__->belongs_to(
    "patron",
    "Koha::Schema::Result::Borrower",
    { borrowernumber => "borrowernumber" },
    { join_type => "LEFT", on_delete => "CASCADE", on_update => "CASCADE" },
);

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
  "library",
  "Koha::Schema::Result::Branch",
  { "foreign.branchcode" => "self.branchcode" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
  },
);

=head2 return_claim

Type: might_have

Related object: L<Koha::Schema::Result::ReturnClaim>

=cut

__PACKAGE__->might_have(
    "return_claim",
    "Koha::Schema::Result::ReturnClaim",
    { "foreign.issue_id" => "self.issue_id" },
    { cascade_copy       => 0, cascade_delete => 0 },
);

sub koha_object_class {
    'Koha::Old::Checkout';
}
sub koha_objects_class {
    'Koha::Old::Checkouts';
}

1;
