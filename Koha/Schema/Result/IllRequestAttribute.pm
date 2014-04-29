use utf8;
package Koha::Schema::Result::IllRequestAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllRequestAttribute

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ill_request_attributes>

=cut

__PACKAGE__->table("ill_request_attributes");

=head1 ACCESSORS

=head2 req_id

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 value

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "req_id",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "value",
  { data_type => "text", is_nullable => 0 },
);

=head1 RELATIONS

=head2 req

Type: belongs_to

Related object: L<Koha::Schema::Result::IllRequest>

=cut

__PACKAGE__->belongs_to(
  "req",
  "Koha::Schema::Result::IllRequest",
  { id => "req_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-10-24 12:47:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AK/udoYUDFUNcgg7r5gpYw

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key(qw/req_id type/);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
