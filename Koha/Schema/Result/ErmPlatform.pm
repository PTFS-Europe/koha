use utf8;
package Koha::Schema::Result::ErmPlatform;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmPlatform

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_platforms>

=cut

__PACKAGE__->table("erm_platforms");

=head1 ACCESSORS

=head2 erm_platform_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

name of the platform

=head2 description

  data_type: 'longtext'
  is_nullable: 1

description of the platform

=cut

__PACKAGE__->add_columns(
  "erm_platform_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "description",
  { data_type => "longtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</erm_platform_id>

=back

=cut

__PACKAGE__->set_primary_key("erm_platform_id");

=head1 RELATIONS

=head2 erm_harvesters

Type: has_many

Related object: L<Koha::Schema::Result::ErmHarvester>

=cut

__PACKAGE__->has_many(
  "erm_harvesters",
  "Koha::Schema::Result::ErmHarvester",
  { "foreign.platform_id" => "self.erm_platform_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 erm_usage_muses

Type: has_many

Related object: L<Koha::Schema::Result::ErmUsageMus>

=cut

__PACKAGE__->has_many(
  "erm_usage_muses",
  "Koha::Schema::Result::ErmUsageMus",
  { "foreign.platform_id" => "self.erm_platform_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 erm_usage_yuses

Type: has_many

Related object: L<Koha::Schema::Result::ErmUsageYus>

=cut

__PACKAGE__->has_many(
  "erm_usage_yuses",
  "Koha::Schema::Result::ErmUsageYus",
  { "foreign.platform_id" => "self.erm_platform_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-03-01 13:24:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:anRRhDzTiVK81ZNvP8dXKg


sub koha_object_class {
    'Koha::ERM::Platform';
}
sub koha_objects_class {
    'Koha::ERM::Platforms';
}

1;
