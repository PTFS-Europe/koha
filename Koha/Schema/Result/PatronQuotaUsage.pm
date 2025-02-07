use utf8;
package Koha::Schema::Result::PatronQuotaUsage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::PatronQuotaUsage

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<patron_quota_usage>

=cut

__PACKAGE__->table("patron_quota_usage");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique identifier for quota usage record

=head2 patron_quota_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key linking to patron_quota.id

=head2 issue_id

  data_type: 'integer'
  is_nullable: 1

linking to issues.issue_id or old_issues.issue_id

=head2 patron_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key linking to borrowers.borrowernumber

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "patron_quota_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "issue_id",
  { data_type => "integer", is_nullable => 1 },
  "patron_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 patron

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "patron",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "patron_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 patron_quota

Type: belongs_to

Related object: L<Koha::Schema::Result::PatronQuota>

=cut

__PACKAGE__->belongs_to(
  "patron_quota",
  "Koha::Schema::Result::PatronQuota",
  { id => "patron_quota_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-02-07 14:14:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/UbHmNOqiKX4ZjaDZOKi0Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
