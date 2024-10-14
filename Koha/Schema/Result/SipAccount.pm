use utf8;
package Koha::Schema::Result::SipAccount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::SipAccount

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sip_accounts>

=cut

__PACKAGE__->table("sip_accounts");

=head1 ACCESSORS

=head2 sip_account_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 sip_institution_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Foreign key to sip_institutions.sip_institution_id

=head2 ae_field_template

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 allow_additional_materials_checkout

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 allow_empty_passwords

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 av_field_template

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 blocked_item_types

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 checked_in_ok

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 cr_item_field

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 ct_always_send

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 cv_send_00_on_success

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 cv_triggers_alert

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 da_field_template

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 delimiter

  data_type: 'varchar'
  default_value: '|'
  is_nullable: 0
  size: 10

=head2 encoding

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 error_detect

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 format_due_date

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 hide_fields

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 holds_block_checkin

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 holds_get_captured

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 inhouse_item_types

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 inhouse_patron_categories

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 login_id

  data_type: 'varchar'
  is_nullable: 0
  size: 255

PREVIOUSLY id in Sipconfig.xml

=head2 login_password

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 lost_status_for_missing

  data_type: 'tinyint'
  is_nullable: 1

actual tinyint, not boolean

=head2 overdues_block_checkout

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 prevcheckout_block_checkout

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 register_id

  data_type: 'integer'
  is_nullable: 1

SHOULD THIS BE A FK TO cash_registers?

=head2 seen_on_item_information

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 send_patron_home_library_in_af

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 show_checkin_message

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 show_outstanding_amount

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 terminator

  data_type: 'enum'
  default_value: 'CRLF'
  extra: {list => ["CR","CRLF"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "sip_account_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "sip_institution_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "ae_field_template",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "allow_additional_materials_checkout",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "allow_empty_passwords",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "av_field_template",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "blocked_item_types",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "checked_in_ok",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "cr_item_field",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "ct_always_send",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "cv_send_00_on_success",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "cv_triggers_alert",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "da_field_template",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "delimiter",
  { data_type => "varchar", default_value => "|", is_nullable => 0, size => 10 },
  "encoding",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "error_detect",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "format_due_date",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "hide_fields",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "holds_block_checkin",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "holds_get_captured",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "inhouse_item_types",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "inhouse_patron_categories",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "login_id",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "login_password",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "lost_status_for_missing",
  { data_type => "tinyint", is_nullable => 1 },
  "overdues_block_checkout",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "prevcheckout_block_checkout",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "register_id",
  { data_type => "integer", is_nullable => 1 },
  "seen_on_item_information",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "send_patron_home_library_in_af",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "show_checkin_message",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "show_outstanding_amount",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "terminator",
  {
    data_type => "enum",
    default_value => "CRLF",
    extra => { list => ["CR", "CRLF"] },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</sip_account_id>

=back

=cut

__PACKAGE__->set_primary_key("sip_account_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<sip_account>

=over 4

=item * L</sip_account_id>

=item * L</sip_institution_id>

=back

=cut

__PACKAGE__->add_unique_constraint("sip_account", ["sip_account_id", "sip_institution_id"]);

=head1 RELATIONS

=head2 sip_institution

Type: belongs_to

Related object: L<Koha::Schema::Result::SipInstitution>

=cut

__PACKAGE__->belongs_to(
  "sip_institution",
  "Koha::Schema::Result::SipInstitution",
  { sip_institution_id => "sip_institution_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2024-10-24 09:50:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vg/OY/9t4JTdpnoJU91o4A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
