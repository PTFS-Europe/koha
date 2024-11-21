use utf8;
package Koha::Schema::Result::FiscalPeriod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::FiscalPeriod

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<fiscal_period>

=cut

__PACKAGE__->table("fiscal_period");

=head1 ACCESSORS

=head2 fiscal_period_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'longtext'
  default_value: ''''
  is_nullable: 1

description for the fiscal period

=head2 code

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 1
  size: 255

code for the fiscal period

=head2 start_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

start date of the event

=head2 end_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

end date of the event

=head2 status

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 1

is the fiscal period currently active

=head2 last_updated

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 1

time of the last update to the fiscal period

=head2 owner_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

owner of the fiscal period

=head2 lib_group_visibility

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 1
  size: 255

library groups the fiscal period is visible to

=cut

__PACKAGE__->add_columns(
  "fiscal_period_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "longtext", default_value => "''", is_nullable => 1 },
  "code",
  { data_type => "varchar", default_value => "", is_nullable => 1, size => 255 },
  "start_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "end_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "status",
  { data_type => "tinyint", default_value => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 1,
  },
  "owner_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "lib_group_visibility",
  { data_type => "varchar", default_value => "", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</fiscal_period_id>

=back

=cut

__PACKAGE__->set_primary_key("fiscal_period_id");

=head1 RELATIONS

=head2 fund_allocations

Type: has_many

Related object: L<Koha::Schema::Result::FundAllocation>

=cut

__PACKAGE__->has_many(
  "fund_allocations",
  "Koha::Schema::Result::FundAllocation",
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 funds

Type: has_many

Related object: L<Koha::Schema::Result::Fund>

=cut

__PACKAGE__->has_many(
  "funds",
  "Koha::Schema::Result::Fund",
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 ledgers

Type: has_many

Related object: L<Koha::Schema::Result::Ledger>

=cut

__PACKAGE__->has_many(
  "ledgers",
  "Koha::Schema::Result::Ledger",
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
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
  { "foreign.fiscal_period_id" => "self.fiscal_period_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2024-11-20 14:37:31
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Smuu04BX3qOZaT/An/Zvvw

__PACKAGE__->add_columns(
    '+status' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Acquisition::FundManagement::FiscalPeriod';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::FiscalPeriods';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
