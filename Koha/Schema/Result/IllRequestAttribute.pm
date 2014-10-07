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
  is_nullable: 1

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
  { data_type => "bigint", is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "value",
  { data_type => "text", is_nullable => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-10-07 15:51:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZbzWtdvcdqZe+9eZzMPQwQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
