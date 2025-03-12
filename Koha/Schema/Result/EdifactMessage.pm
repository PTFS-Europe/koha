use utf8;
package Koha::Schema::Result::EdifactMessage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::EdifactMessage

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<edifact_messages>

=cut

__PACKAGE__->table("edifact_messages");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 message_type

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 transfer_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 vendor_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 edi_acct

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 status

  data_type: 'mediumtext'
  is_nullable: 1

=head2 basketno

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 raw_msg

  data_type: 'longtext'
  is_nullable: 1

=head2 filename

  data_type: 'mediumtext'
  is_nullable: 1

=head2 deleted

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "message_type",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "transfer_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "vendor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "edi_acct",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "status",
  { data_type => "mediumtext", is_nullable => 1 },
  "basketno",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "raw_msg",
  { data_type => "longtext", is_nullable => 1 },
  "filename",
  { data_type => "mediumtext", is_nullable => 1 },
  "deleted",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 aqinvoices

Type: has_many

Related object: L<Koha::Schema::Result::Aqinvoice>

=cut

__PACKAGE__->has_many(
  "aqinvoices",
  "Koha::Schema::Result::Aqinvoice",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 basketno

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbasket>

=cut

__PACKAGE__->belongs_to(
  "basketno",
  "Koha::Schema::Result::Aqbasket",
  { basketno => "basketno" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 edi_acct

Type: belongs_to

Related object: L<Koha::Schema::Result::VendorEdiAccount>

=cut

__PACKAGE__->belongs_to(
  "edi_acct",
  "Koha::Schema::Result::VendorEdiAccount",
  { id => "edi_acct" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 edifact_errors

Type: has_many

Related object: L<Koha::Schema::Result::EdifactError>

=cut

__PACKAGE__->has_many(
  "edifact_errors",
  "Koha::Schema::Result::EdifactError",
  { "foreign.message_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vendor

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbookseller>

=cut

__PACKAGE__->belongs_to(
  "vendor",
  "Koha::Schema::Result::Aqbookseller",
  { id => "vendor_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-02-21 15:22:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eQY+yK0Wkf01y4X30dg2aA

__PACKAGE__->add_columns(
    '+deleted' => { is_boolean => 1 },
);

=head2 koha_objects_class

=cut

sub koha_objects_class {
    'Koha::Edifact::Files';
}

=head2 koha_object_class

=cut

sub koha_object_class {
    'Koha::Edifact::File';
}

1;
