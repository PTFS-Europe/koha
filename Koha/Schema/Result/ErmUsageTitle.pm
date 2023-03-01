use utf8;
package Koha::Schema::Result::ErmUsageTitle;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmUsageTitle

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_usage_titles>

=cut

__PACKAGE__->table("erm_usage_titles");

=head1 ACCESSORS

=head2 title_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 255

item title

=cut

__PACKAGE__->add_columns(
  "title_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</title_id>

=back

=cut

__PACKAGE__->set_primary_key("title_id");

=head1 RELATIONS

=head2 erm_usage_muses

Type: has_many

Related object: L<Koha::Schema::Result::ErmUsageMus>

=cut

__PACKAGE__->has_many(
  "erm_usage_muses",
  "Koha::Schema::Result::ErmUsageMus",
  { "foreign.title_id" => "self.title_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 erm_usage_yuses

Type: has_many

Related object: L<Koha::Schema::Result::ErmUsageYus>

=cut

__PACKAGE__->has_many(
  "erm_usage_yuses",
  "Koha::Schema::Result::ErmUsageYus",
  { "foreign.title_id" => "self.title_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-02-22 11:59:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JRRiiqrSOFhSqIrTn5RYIg


sub koha_object_class {
    'Koha::ERM::UsageTitle';
}
sub koha_objects_class {
    'Koha::ERM::UsageTitles';
}

1;
