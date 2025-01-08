use utf8;
package Koha::Schema::Result::Fund;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Fund

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<funds>

=cut

__PACKAGE__->table("funds");

=head1 ACCESSORS

=head2 fund_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 ledger_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

ledger the fund applies to

=head2 fiscal_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fiscal period the fund applies to

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

name for the fund

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the fund

=head2 fund_type

  data_type: 'varchar'
  is_nullable: 1
  size: 255

type for the fund

=head2 fund_group_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

group for the fund

=head2 code

  data_type: 'varchar'
  is_nullable: 1
  size: 255

code for the fund

=head2 external_id

  data_type: 'varchar'
  is_nullable: 1
  size: 255

external id for the fund for use with external accounting systems

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the fund

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the fund currently active

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the fund

=head2 spend_limit

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

spend limit for the fund

=head2 over_spend_allowed

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is an overspend allowed on the fund

=head2 oe_warning_percent

  data_type: 'decimal'
  default_value: 0.0000
  is_nullable: 1
  size: [5,4]

percentage limit for overencumbrance

=head2 oe_limit_amount

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

limit for overspend

=head2 os_warning_sum

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

amount to trigger a warning for overspend

=head2 os_limit_sum

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

amount to trigger a block on the fund for overspend

=head2 last_updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the fund

=head2 lib_group_visibility

  data_type: 'varchar'
  is_nullable: 1
  size: 255

library groups the fund is visible to

=cut

__PACKAGE__->add_columns(
  "fund_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "ledger_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fiscal_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "fund_type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fund_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "external_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "status",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "spend_limit",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "over_spend_allowed",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "oe_warning_percent",
  {
    data_type => "decimal",
    default_value => "0.0000",
    is_nullable => 1,
    size => [5, 4],
  },
  "oe_limit_amount",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "os_warning_sum",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "os_limit_sum",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
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

=item * L</fund_id>

=back

=cut

__PACKAGE__->set_primary_key("fund_id");

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

=head2 fund_allocations

Type: has_many

Related object: L<Koha::Schema::Result::FundAllocation>

=cut

__PACKAGE__->has_many(
  "fund_allocations",
  "Koha::Schema::Result::FundAllocation",
  { "foreign.fund_id" => "self.fund_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 fund_group

Type: belongs_to

Related object: L<Koha::Schema::Result::FundGroup>

=cut

__PACKAGE__->belongs_to(
  "fund_group",
  "Koha::Schema::Result::FundGroup",
  { fund_group_id => "fund_group_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
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

=head2 sub_funds

Type: has_many

Related object: L<Koha::Schema::Result::SubFund>

=cut

__PACKAGE__->has_many(
  "sub_funds",
  "Koha::Schema::Result::SubFund",
  { "foreign.fund_id" => "self.fund_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-01-08 12:27:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d6Sf1znS+8Pil6KDJqfxyw

__PACKAGE__->add_columns(
    '+status' => { is_boolean => 1 },
    '+over_spend_allowed' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::Fund';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::Funds';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
