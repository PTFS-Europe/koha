use utf8;
package Koha::Schema::Result::ShibbolethFieldMapping;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ShibbolethFieldMapping

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<shibboleth_field_mappings>

=cut

__PACKAGE__->table("shibboleth_field_mappings");

=head1 ACCESSORS

=head2 mapping_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 idp_field

  data_type: 'varchar'
  is_nullable: 0
  size: 255

field name from the identity provider

=head2 koha_field

  data_type: 'varchar'
  is_nullable: 0
  size: 255

corresponding field in Koha borrowers table

=head2 is_matchpoint

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

if this field is used to match existing users

=cut

__PACKAGE__->add_columns(
  "mapping_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "idp_field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "koha_field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "is_matchpoint",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</mapping_id>

=back

=cut

__PACKAGE__->set_primary_key("mapping_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<idp_field_idx>

=over 4

=item * L</idp_field>

=back

=cut

__PACKAGE__->add_unique_constraint("idp_field_idx", ["idp_field"]);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-02-18 15:47:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uK63fJc0tz3UNVRQCK4lAg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
