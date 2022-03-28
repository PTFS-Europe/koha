use utf8;
package Koha::Schema::Result::L10nSource;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::L10nSource

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<l10n_source>

=cut

__PACKAGE__->table("l10n_source");

=head1 ACCESSORS

=head2 l10n_source_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 group

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 key

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 text

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "l10n_source_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "group",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "key",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "text",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</l10n_source_id>

=back

=cut

__PACKAGE__->set_primary_key("l10n_source_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<group_key>

=over 4

=item * L</group>

=item * L</key>

=back

=cut

__PACKAGE__->add_unique_constraint("group_key", ["group", "key"]);

=head1 RELATIONS

=head2 l10n_targets

Type: has_many

Related object: L<Koha::Schema::Result::L10nTarget>

=cut

__PACKAGE__->has_many(
  "l10n_targets",
  "Koha::Schema::Result::L10nTarget",
  { "foreign.l10n_source_id" => "self.l10n_source_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-28 15:03:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QRPw3vO+2BbF4AmGCuucGw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
