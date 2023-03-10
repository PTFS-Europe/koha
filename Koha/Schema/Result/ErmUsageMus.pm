use utf8;
package Koha::Schema::Result::ErmUsageMus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ErmUsageMus

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<erm_usage_mus>

=cut

__PACKAGE__->table("erm_usage_mus");

=head1 ACCESSORS

=head2 monthly_usage_summary_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 title_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

item title id number

=head2 platform_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

item title id number

=head2 year

  data_type: 'integer'
  is_nullable: 1

year of usage statistics

=head2 month

  data_type: 'integer'
  is_nullable: 1

month of usage statistics

=head2 usage_count

  data_type: 'integer'
  is_nullable: 1

usage count for the title

=cut

__PACKAGE__->add_columns(
  "monthly_usage_summary_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "title_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "platform_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "year",
  { data_type => "integer", is_nullable => 1 },
  "month",
  { data_type => "integer", is_nullable => 1 },
  "usage_count",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</monthly_usage_summary_id>

=back

=cut

__PACKAGE__->set_primary_key("monthly_usage_summary_id");

=head1 RELATIONS

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

=head2 title

Type: belongs_to

Related object: L<Koha::Schema::Result::ErmUsageTitle>

=cut

__PACKAGE__->belongs_to(
  "title",
  "Koha::Schema::Result::ErmUsageTitle",
  { title_id => "title_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-03-01 13:24:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q1xTS9288msZG8GcVXUr7g


sub koha_object_class {
    'Koha::ERM::MonthlyUsage';
}
sub koha_objects_class {
    'Koha::ERM::MonthlyUsages';
}

1;
