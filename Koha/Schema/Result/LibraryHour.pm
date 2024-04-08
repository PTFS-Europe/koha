use utf8;
package Koha::Schema::Result::LibraryHour;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::LibraryHour

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<library_hours>

=cut

__PACKAGE__->table("library_hours");

=head1 ACCESSORS

=head2 library_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 10

=head2 day

  data_type: 'enum'
  default_value: 0
  extra: {list => [0,1,2,3,4,5,6]}
  is_nullable: 0

=head2 open_time

  data_type: 'time'
  is_nullable: 1

=head2 close_time

  data_type: 'time'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "library_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 10 },
  "day",
  {
    data_type => "enum",
    default_value => 0,
    extra => { list => [0 .. 6] },
    is_nullable => 0,
  },
  "open_time",
  { data_type => "time", is_nullable => 1 },
  "close_time",
  { data_type => "time", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</library_id>

=item * L</day>

=back

=cut

__PACKAGE__->set_primary_key("library_id", "day");

=head1 RELATIONS

=head2 library

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "library",
  "Koha::Schema::Result::Branch",
  { branchcode => "library_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2023-10-09 04:50:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+HaRcwTHecetQRA+fNytTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
