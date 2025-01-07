use utf8;
package Koha::Schema::Result::FundAllocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::FundAllocation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<fund_allocation>

=cut

__PACKAGE__->table("fund_allocation");

=head1 ACCESSORS

=head2 fund_allocation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fund the fund allocation applies to

=head2 sub_fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

sub fund the fund allocation applies to

=head2 ledger_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

ledger the fund allocation applies to

=head2 fiscal_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fiscal period the fund allocation applies to

=head2 allocation_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

amount for the allocation

=head2 reference

  data_type: 'varchar'
  is_nullable: 1
  size: 255

allocation reference

=head2 note

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

any notes associated to the allocation

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the fund allocation

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the fund allocation

=head2 type

  data_type: 'enum'
  extra: {list => ["encumbered","spent","transfer","credit"]}
  is_nullable: 1

type of the fund allocation

=head2 is_transfer

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

is the fund allocation a transfer to/from another fund

=head2 last_updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the fund allocation

=head2 lib_group_visibility

  data_type: 'varchar'
  is_nullable: 1
  size: 255

library groups the fund allocation is visible to

=cut

__PACKAGE__->add_columns(
  "fund_allocation_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sub_fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ledger_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fiscal_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "allocation_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "reference",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "note",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "type",
  {
    data_type => "enum",
    extra => { list => ["encumbered", "spent", "transfer", "credit"] },
    is_nullable => 1,
  },
  "is_transfer",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "last_updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "lib_group_visibility",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</fund_allocation_id>

=back

=cut

__PACKAGE__->set_primary_key("fund_allocation_id");

=head1 RELATIONS

=head2 fiscal_period

Type: belongs_to

Related object: L<Koha::Schema::Result::FiscalPeriod>

=cut

__PACKAGE__->belongs_to(
  "fiscal_period",
  "Koha::Schema::Result::FiscalPeriod",
  { fiscal_period_id => "fiscal_period_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 fund

Type: belongs_to

Related object: L<Koha::Schema::Result::Fund>

=cut

__PACKAGE__->belongs_to(
  "fund",
  "Koha::Schema::Result::Fund",
  { fund_id => "fund_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 ledger

Type: belongs_to

Related object: L<Koha::Schema::Result::Ledger>

=cut

__PACKAGE__->belongs_to(
  "ledger",
  "Koha::Schema::Result::Ledger",
  { ledger_id => "ledger_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 owner

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "owner",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "owner_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 sub_fund

Type: belongs_to

Related object: L<Koha::Schema::Result::SubFund>

=cut

__PACKAGE__->belongs_to(
  "sub_fund",
  "Koha::Schema::Result::SubFund",
  { sub_fund_id => "sub_fund_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-01-07 11:02:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KhE/vYplvFdV01hwOO6EYQ

__PACKAGE__->add_columns(
    '+is_transfer' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::FundAllocation';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::FundAllocations';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
