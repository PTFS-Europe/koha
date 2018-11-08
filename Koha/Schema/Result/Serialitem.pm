use utf8;
package Koha::Schema::Result::Serialitem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Serialitem

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<serialitems>

=cut

__PACKAGE__->table("serialitems");

=head1 ACCESSORS

=head2 itemnumber

  data_type: 'integer'
  is_nullable: 0

=head2 serialid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "itemnumber",
  { data_type => "integer", is_nullable => 0 },
  "serialid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</itemnumber>

=back

=cut

__PACKAGE__->set_primary_key("itemnumber");

=head1 RELATIONS

=head2 serialid

Type: belongs_to

Related object: L<Koha::Schema::Result::Serial>

=cut

__PACKAGE__->belongs_to(
  "serialid",
  "Koha::Schema::Result::Serial",
  { serialid => "serialid" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-11-08 11:09:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qAF0pJF5e8AJzxaZqlg13w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
