use utf8;
package Koha::Schema::Result::PatronQuota;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::PatronQuota

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<patron_quota>

=cut

__PACKAGE__->table("patron_quota");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique identifier for the quota record

=head2 description

  data_type: 'longtext'
  is_nullable: 0

user friendly description for the quota record

=head2 patron_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key linking to borrowers.borrowernumber

=head2 allocation

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

total quota allocation for the period

=head2 used

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

amount of allocation used for current period

=head2 start_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

start date of the allocation period

=head2 end_date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

end date of the allocation period

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "longtext", is_nullable => 0 },
  "patron_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "used",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "start_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "end_date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
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

=head2 patron_quota_usages

Type: has_many

Related object: L<Koha::Schema::Result::PatronQuotaUsage>

=cut

__PACKAGE__->has_many(
  "patron_quota_usages",
  "Koha::Schema::Result::PatronQuotaUsage",
  { "foreign.patron_quota_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-01-30 16:04:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KG/MIjPSLcpeSlPypwli2Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
