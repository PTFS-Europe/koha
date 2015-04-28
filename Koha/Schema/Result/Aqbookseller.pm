use utf8;
package Koha::Schema::Result::Aqbookseller;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Aqbookseller

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqbooksellers>

=cut

__PACKAGE__->table("aqbooksellers");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'mediumtext'
  is_nullable: 0

=head2 address1

  data_type: 'mediumtext'
  is_nullable: 1

=head2 address2

  data_type: 'mediumtext'
  is_nullable: 1

=head2 address3

  data_type: 'mediumtext'
  is_nullable: 1

=head2 address4

  data_type: 'mediumtext'
  is_nullable: 1

=head2 phone

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 accountnumber

  data_type: 'mediumtext'
  is_nullable: 1

=head2 othersupplier

  data_type: 'mediumtext'
  is_nullable: 1

=head2 currency

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 3

=head2 booksellerfax

  data_type: 'mediumtext'
  is_nullable: 1

=head2 notes

  data_type: 'mediumtext'
  is_nullable: 1

=head2 bookselleremail

  data_type: 'mediumtext'
  is_nullable: 1

=head2 booksellerurl

  data_type: 'mediumtext'
  is_nullable: 1

=head2 postal

  data_type: 'mediumtext'
  is_nullable: 1

=head2 url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 active

  data_type: 'tinyint'
  is_nullable: 1

=head2 listprice

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 invoiceprice

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 gstreg

  data_type: 'tinyint'
  is_nullable: 1

=head2 listincgst

  data_type: 'tinyint'
  is_nullable: 1

=head2 invoiceincgst

  data_type: 'tinyint'
  is_nullable: 1

=head2 gstrate

  data_type: 'decimal'
  is_nullable: 1
  size: [6,4]

=head2 discount

  data_type: 'float'
  is_nullable: 1
  size: [6,4]

=head2 fax

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 deliverytime

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "mediumtext", is_nullable => 0 },
  "address1",
  { data_type => "mediumtext", is_nullable => 1 },
  "address2",
  { data_type => "mediumtext", is_nullable => 1 },
  "address3",
  { data_type => "mediumtext", is_nullable => 1 },
  "address4",
  { data_type => "mediumtext", is_nullable => 1 },
  "phone",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "accountnumber",
  { data_type => "mediumtext", is_nullable => 1 },
  "othersupplier",
  { data_type => "mediumtext", is_nullable => 1 },
  "currency",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 3 },
  "booksellerfax",
  { data_type => "mediumtext", is_nullable => 1 },
  "notes",
  { data_type => "mediumtext", is_nullable => 1 },
  "bookselleremail",
  { data_type => "mediumtext", is_nullable => 1 },
  "booksellerurl",
  { data_type => "mediumtext", is_nullable => 1 },
  "postal",
  { data_type => "mediumtext", is_nullable => 1 },
  "url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "active",
  { data_type => "tinyint", is_nullable => 1 },
  "listprice",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "invoiceprice",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "gstreg",
  { data_type => "tinyint", is_nullable => 1 },
  "listincgst",
  { data_type => "tinyint", is_nullable => 1 },
  "invoiceincgst",
  { data_type => "tinyint", is_nullable => 1 },
  "gstrate",
  { data_type => "decimal", is_nullable => 1, size => [6, 4] },
  "discount",
  { data_type => "float", is_nullable => 1, size => [6, 4] },
  "fax",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "deliverytime",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 aqbasketgroups

Type: has_many

Related object: L<Koha::Schema::Result::Aqbasketgroup>

=cut

__PACKAGE__->has_many(
  "aqbasketgroups",
  "Koha::Schema::Result::Aqbasketgroup",
  { "foreign.booksellerid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 aqbaskets

Type: has_many

Related object: L<Koha::Schema::Result::Aqbasket>

=cut

__PACKAGE__->has_many(
  "aqbaskets",
  "Koha::Schema::Result::Aqbasket",
  { "foreign.booksellerid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 aqcontacts

Type: has_many

Related object: L<Koha::Schema::Result::Aqcontact>

=cut

__PACKAGE__->has_many(
  "aqcontacts",
  "Koha::Schema::Result::Aqcontact",
  { "foreign.booksellerid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 aqcontracts

Type: has_many

Related object: L<Koha::Schema::Result::Aqcontract>

=cut

__PACKAGE__->has_many(
  "aqcontracts",
  "Koha::Schema::Result::Aqcontract",
  { "foreign.booksellerid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 aqinvoices

Type: has_many

Related object: L<Koha::Schema::Result::Aqinvoice>

=cut

__PACKAGE__->has_many(
  "aqinvoices",
  "Koha::Schema::Result::Aqinvoice",
  { "foreign.booksellerid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 invoiceprice

Type: belongs_to

Related object: L<Koha::Schema::Result::Currency>

=cut

__PACKAGE__->belongs_to(
  "invoiceprice",
  "Koha::Schema::Result::Currency",
  { currency => "invoiceprice" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 listprice

Type: belongs_to

Related object: L<Koha::Schema::Result::Currency>

=cut

__PACKAGE__->belongs_to(
  "listprice",
  "Koha::Schema::Result::Currency",
  { currency => "listprice" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-08-26 11:53:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kz1tuPJihENyV6OyCwyX/A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
