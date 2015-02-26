use utf8;
package Koha::Schema::Result::CashTranscode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashTranscode

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_transcode>

=cut

__PACKAGE__->table("cash_transcode");

=head1 ACCESSORS

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 100

=head2 income_group

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 taxrate

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 visible_charge

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 archived

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "code",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 100 },
  "income_group",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "taxrate",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "visible_charge",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "archived",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->set_primary_key("code");

=head1 RELATIONS

=head2 cash_transactions

Type: has_many

Related object: L<Koha::Schema::Result::CashTransaction>

=cut

__PACKAGE__->has_many(
  "cash_transactions",
  "Koha::Schema::Result::CashTransaction",
  { "foreign.tcode" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-02-26 05:47:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7eyl/xTvKOreIN1DdRmvRw
__PACKAGE__->load_components(qw( FilterColumn ));
__PACKAGE__->filter_column(
    visible_charge => {
        filter_to_storage => sub { $_[1] ? 1 : 0 },
    },
    archived => {
        filter_to_storage => sub { $_[1] ? 1 : 0 },
    }
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
