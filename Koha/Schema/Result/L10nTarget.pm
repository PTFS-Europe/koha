use utf8;
package Koha::Schema::Result::L10nTarget;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::L10nTarget

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<l10n_target>

=cut

__PACKAGE__->table("l10n_target");

=head1 ACCESSORS

=head2 l10n_target_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 l10n_source_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 language

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 translation

  data_type: 'text'
  is_nullable: 0

=head2 fuzzy

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "l10n_target_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "l10n_source_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "language",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "translation",
  { data_type => "text", is_nullable => 0 },
  "fuzzy",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</l10n_target_id>

=back

=cut

__PACKAGE__->set_primary_key("l10n_target_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<l10n_source_language>

=over 4

=item * L</l10n_source_id>

=item * L</language>

=back

=cut

__PACKAGE__->add_unique_constraint("l10n_source_language", ["l10n_source_id", "language"]);

=head1 RELATIONS

=head2 l10n_source

Type: belongs_to

Related object: L<Koha::Schema::Result::L10nSource>

=cut

__PACKAGE__->belongs_to(
  "l10n_source",
  "Koha::Schema::Result::L10nSource",
  { l10n_source_id => "l10n_source_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-28 15:03:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oXnI0NR9rifXbtfWYqcxzg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
