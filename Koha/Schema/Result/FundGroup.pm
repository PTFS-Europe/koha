use utf8;
package Koha::Schema::Result::FundGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::FundGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<fund_group>

=cut

__PACKAGE__->table("fund_group");

=head1 ACCESSORS

=head2 fund_group_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

name for the fund group

=head2 currency

  data_type: 'varchar'
  is_nullable: 1
  size: 10

currency of the fund allocation

=head2 lib_group_visibility

  data_type: 'varchar'
  is_nullable: 1
  size: 255

library groups the fund allocation is visible to

=cut

__PACKAGE__->add_columns(
  "fund_group_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "lib_group_visibility",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</fund_group_id>

=back

=cut

__PACKAGE__->set_primary_key("fund_group_id");

=head1 RELATIONS

=head2 funds

Type: has_many

Related object: L<Koha::Schema::Result::Fund>

=cut

__PACKAGE__->has_many(
  "funds",
  "Koha::Schema::Result::Fund",
  { "foreign.fund_group_id" => "self.fund_group_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2024-12-30 13:46:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZokNYrWcp6oyR3wVeJekuw

sub koha_object_class {
    'Koha::Acquisition::FundManagement::FundGroup';
}

sub koha_objects_class {
    'Koha::Acquisition::FundManagement::FundGroups';
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
