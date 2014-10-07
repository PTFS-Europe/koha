use utf8;
package Koha::Schema::Result::IllRequest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::IllRequest

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ill_requests>

=cut

__PACKAGE__->table("ill_requests");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 1

=head2 biblionumber

  data_type: 'integer'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 placement_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 reply_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 ts

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 completion_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 reqtype

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 branch

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "borrowernumber",
  { data_type => "integer", is_nullable => 1 },
  "biblionumber",
  { data_type => "integer", is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "placement_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "reply_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "ts",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "completion_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "reqtype",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "branch",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2014-10-07 15:51:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zaYkDhiGH75nXSEUWs0bEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
