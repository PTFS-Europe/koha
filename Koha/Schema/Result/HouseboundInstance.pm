use utf8;
package Koha::Schema::Result::HouseboundInstance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::HouseboundInstance

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<housebound_instance>

=cut

__PACKAGE__->table("housebound_instance");

=head1 ACCESSORS

=head2 instanceid

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 hbnumber

  data_type: 'integer'
  is_nullable: 0

=head2 dmy

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 time

  data_type: 'mediumtext'
  is_nullable: 1

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 0

=head2 volunteer

  data_type: 'integer'
  is_nullable: 1

=head2 chooser

  data_type: 'integer'
  is_nullable: 1

=head2 deliverer

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "instanceid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "hbnumber",
  { data_type => "integer", is_nullable => 0 },
  "dmy",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "time",
  { data_type => "mediumtext", is_nullable => 1 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 0 },
  "volunteer",
  { data_type => "integer", is_nullable => 1 },
  "chooser",
  { data_type => "integer", is_nullable => 1 },
  "deliverer",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</instanceid>

=back

=cut

__PACKAGE__->set_primary_key("instanceid");


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2018-11-08 11:09:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Hi6YuuVAE9fKyyEi8DPhUA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
