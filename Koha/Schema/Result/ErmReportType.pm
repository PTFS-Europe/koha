use utf8;
package Koha::Schema::Result::ErmReportType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmReportType

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_report_types>

=cut

__PACKAGE__->table("erm_report_types");

=head1 ACCESSORS

=head2 erm_report_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 harvester_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key to erm_harvester

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 255

report type

=cut

__PACKAGE__->add_columns(
  "erm_report_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "harvester_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</erm_report_id>

=back

=cut

__PACKAGE__->set_primary_key("erm_report_id");

=head1 RELATIONS

=head2 harvester

Type: belongs_to

Related object: L<Koha::Schema::Result::ErmHarvester>

=cut

__PACKAGE__->belongs_to(
  "harvester",
  "Koha::Schema::Result::ErmHarvester",
  { erm_harvester_id => "harvester_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-03-01 13:22:40
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tRHoSIrNxOlMPy2/nAj0Gg


sub koha_object_class {
    'Koha::ERM::ReportType';
}
sub koha_objects_class {
    'Koha::ERM::ReportTypes';
}
1;
