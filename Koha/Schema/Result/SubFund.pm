use utf8;
package Koha::Schema::Result::SubFund;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::SubFund

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sub_funds>

=cut

__PACKAGE__->table("sub_funds");

=head1 ACCESSORS

=head2 sub_fund_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 fund_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

parent fund for the sub fund

=head2 ledger_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

ledger the sub_fund applies to

=head2 fiscal_period_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

fiscal period the sub_fund applies to

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

name for the sub_fund

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the sub_fund

=head2 sub_fund_type

  data_type: 'varchar'
  is_nullable: 1
  size: 255

type for the sub_fund

=head2 code

  data_type: 'varchar'
  is_nullable: 1
  size: 255

code for the sub_fund

=head2 external_id

  data_type: 'varchar'
  is_nullable: 1
  size: 255

external id for the sub_fund for use with external accounting systems

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the sub_fund

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the sub_fund currently active

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the sub_fund

=head2 spend_limit

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

spend limit for the sub_fund

=head2 sub_fund_value

  data_type: 'decimal'
  default_value: 0.00
  is_nullable: 1
  size: [28,2]

value of the sub_fund

=head2 over_spend_allowed

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is an overspend allowed on the sub_fund

=head2 over_encumbrance_allowed

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is an overencumbrance allowed on the sub_fund

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

amount to trigger a block on the sub_fund for overspend

=head2 last_updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

time of the last update to the sub_fund

=head2 lib_group_visibility

  data_type: 'varchar'
  is_nullable: 1
  size: 255

library groups the sub_fund is visible to

=cut

__PACKAGE__->add_columns(
  "sub_fund_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "fund_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ledger_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fiscal_period_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "sub_fund_type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
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
  "sub_fund_value",
  {
    data_type => "decimal",
    default_value => "0.00",
    is_nullable => 1,
    size => [28, 2],
  },
  "over_spend_allowed",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "over_encumbrance_allowed",
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

=item * L</sub_fund_id>

=back

=cut

__PACKAGE__->set_primary_key("sub_fund_id");

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

=head2 fund_allocations

Type: has_many

Related object: L<Koha::Schema::Result::FundAllocation>

=cut

__PACKAGE__->has_many(
  "fund_allocations",
  "Koha::Schema::Result::FundAllocation",
  { "foreign.sub_fund_id" => "self.sub_fund_id" },
  { cascade_copy => 0, cascade_delete => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-01-02 14:35:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sJtaffK8wdV/LnPlEtftUQ

__PACKAGE__->add_columns(
    '+status' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::SubFund';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::SubFunds';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
