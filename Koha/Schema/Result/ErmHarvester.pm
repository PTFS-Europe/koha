use utf8;
package Koha::Schema::Result::ErmHarvester;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmHarvester

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_harvesters>

=cut

__PACKAGE__->table("erm_harvesters");

=head1 ACCESSORS

=head2 erm_harvester_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 platform_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

foreign key to erm_platform

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 80

current status of the harvester

=head2 method

  data_type: 'varchar'
  is_nullable: 1
  size: 80

method of the harvester

=head2 aggregator

  data_type: 'varchar'
  is_nullable: 1
  size: 80

aggregator of the harvester

=head2 service_type

  data_type: 'varchar'
  is_nullable: 1
  size: 80

service_type of the harvester

=head2 service_url

  data_type: 'varchar'
  is_nullable: 1
  size: 80

service_url of the harvester

=head2 report_release

  data_type: 'varchar'
  is_nullable: 1
  size: 80

report_release of the harvester

=head2 begin_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

start date of the harvester

=head2 end_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

end date of the harvester

=head2 customer_id

  data_type: 'varchar'
  is_nullable: 0
  size: 50

sushi customer id

=head2 requestor_id

  data_type: 'varchar'
  is_nullable: 1
  size: 50

sushi requestor id

=head2 api_key

  data_type: 'varchar'
  is_nullable: 1
  size: 80

sushi api key

=head2 platform

  data_type: 'varchar'
  is_nullable: 1
  size: 80

platform name

=head2 requestor_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

requestor name

=head2 requestor_email

  data_type: 'varchar'
  is_nullable: 1
  size: 80

requestor email

=head2 report_types

  data_type: 'varchar'
  is_nullable: 0
  size: 255

report types provided by the harvester

=cut

__PACKAGE__->add_columns(
  "erm_harvester_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "platform_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "method",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "aggregator",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "service_type",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "service_url",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "report_release",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "begin_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "end_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "customer_id",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "requestor_id",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "api_key",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "platform",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "requestor_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "requestor_email",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "report_types",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</erm_harvester_id>

=back

=cut

__PACKAGE__->set_primary_key("erm_harvester_id");

=head1 RELATIONS

=head2 erm_counter_files

Type: has_many

Related object: L<Koha::Schema::Result::ErmCounterFile>

=cut

__PACKAGE__->has_many(
  "erm_counter_files",
  "Koha::Schema::Result::ErmCounterFile",
  { "foreign.harvester_id" => "self.erm_harvester_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 platform

Type: belongs_to

Related object: L<Koha::Schema::Result::ErmPlatform>

=cut

__PACKAGE__->belongs_to(
  "platform",
  "Koha::Schema::Result::ErmPlatform",
  { erm_platform_id => "platform_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-03-09 16:56:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HgV9+ZpzltT2JEemdieegg

sub koha_object_class {
    'Koha::ERM::Harvester';
}
sub koha_objects_class {
    'Koha::ERM::Harvesters';
}

1;
