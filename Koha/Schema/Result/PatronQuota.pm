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

=head2 quota_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

unique identifier for the quota record

=head2 patron_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

foreign key linking to borrowers.borrowernumber

=head2 quota_total

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

total quota allocation for the period

=head2 quota_used

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

units used within the current period

=head2 period_start

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

start date of the allocation period

=head2 period_end

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

end date of the allocation period

=cut

__PACKAGE__->add_columns(
  "quota_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "patron_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "quota_total",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "quota_used",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "period_start",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "period_end",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</quota_id>

=back

=cut

__PACKAGE__->set_primary_key("quota_id");

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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-01-15 14:23:34
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jVwg3AqHZ+VDXf/GOyGOgA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
