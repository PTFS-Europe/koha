use utf8;
package Koha::Schema::Result::IllbatchStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllbatchStatus

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<illbatch_statuses>

=cut

__PACKAGE__->table("illbatch_statuses");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 is_system

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "is_system",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<u_illbatchstatuses__code>

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->add_unique_constraint("u_illbatchstatuses__code", ["code"]);

=head1 RELATIONS

=head2 illbatches

Type: has_many

Related object: L<Koha::Schema::Result::Illbatch>

=cut

__PACKAGE__->has_many(
  "illbatches",
  "Koha::Schema::Result::Illbatch",
  { "foreign.statuscode" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-04-28 11:24:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LUHcLxj5W4tParGOEkVCdg

__PACKAGE__->add_columns(
    '+is_system' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::IllbatchStatus';
}

sub koha_objects_class {
    'Koha::IllbatchStatuses';
}

1;
