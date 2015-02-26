use utf8;
package Koha::Schema::Result::CashTransaction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashTransaction

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_transaction>

=cut

__PACKAGE__->table("cash_transaction");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 created

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 amt

  data_type: 'decimal'
  is_nullable: 0
  size: [12,2]

=head2 till

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tcode

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 10

=head2 paymenttype

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 receiptid

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "amt",
  { data_type => "decimal", is_nullable => 0, size => [12, 2] },
  "till",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tcode",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 10 },
  "paymenttype",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "receiptid",
  { data_type => "varchar", is_nullable => 1, size => 16 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 tcode

Type: belongs_to

Related object: L<Koha::Schema::Result::CashTranscode>

=cut

__PACKAGE__->belongs_to(
  "tcode",
  "Koha::Schema::Result::CashTranscode",
  { code => "tcode" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 till

Type: belongs_to

Related object: L<Koha::Schema::Result::CashTill>

=cut

__PACKAGE__->belongs_to(
  "till",
  "Koha::Schema::Result::CashTill",
  { tillid => "till" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-02-26 16:05:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vn/i9etct5FaTJpVFh64lg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
