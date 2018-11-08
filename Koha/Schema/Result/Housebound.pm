use utf8;
package Koha::Schema::Result::Housebound;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Housebound

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<housebound>

=cut

__PACKAGE__->table("housebound");

=head1 ACCESSORS

=head2 hbnumber

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 day

  data_type: 'mediumtext'
  is_nullable: 0

=head2 frequency

  data_type: 'mediumtext'
  is_nullable: 1

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 1

=head2 Itype_quant

  accessor: 'itype_quant'
  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 Item_subject

  accessor: 'item_subject'
  data_type: 'mediumtext'
  is_nullable: 1

=head2 Item_authors

  accessor: 'item_authors'
  data_type: 'mediumtext'
  is_nullable: 1

=head2 referral

  data_type: 'mediumtext'
  is_nullable: 1

=head2 notes

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "hbnumber",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "day",
  { data_type => "mediumtext", is_nullable => 0 },
  "frequency",
  { data_type => "mediumtext", is_nullable => 1 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 1 },
  "Itype_quant",
  {
    accessor => "itype_quant",
    data_type => "varchar",
    is_nullable => 1,
    size => 10,
  },
  "Item_subject",
  { accessor => "item_subject", data_type => "mediumtext", is_nullable => 1 },
  "Item_authors",
  { accessor => "item_authors", data_type => "mediumtext", is_nullable => 1 },
  "referral",
  { data_type => "mediumtext", is_nullable => 1 },
  "notes",
  { data_type => "mediumtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</hbnumber>

=back

=cut

__PACKAGE__->set_primary_key("hbnumber");


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-11-08 11:09:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KfWOT6B9V4lGTxfWOE+QTQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
