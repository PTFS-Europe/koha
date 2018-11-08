use utf8;
package Koha::Schema::Result::Ethnicity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Ethnicity

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ethnicity>

=cut

__PACKAGE__->table("ethnicity");

=head1 ACCESSORS

=head2 code

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "code",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->set_primary_key("code");


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-11-08 11:09:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qu8cssBwlX7MIpoFZ6Xvlg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
