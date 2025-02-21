use utf8;
package Koha::Schema::Result::ShibbolethConfig;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ShibbolethConfig

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<shibboleth_config>

=cut

__PACKAGE__->table("shibboleth_config");

=head1 ACCESSORS

=head2 shibboleth_config_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

primary key

=head2 force_opac_sso

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force Shibboleth SSO for OPAC

=head2 force_staff_sso

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Force Shibboleth SSO for staff interface

=head2 autocreate

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Automatically create new patrons

=head2 sync

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Sync patron attributes on login

=head2 welcome

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

Send welcome email to new patrons

=cut

__PACKAGE__->add_columns(
  "shibboleth_config_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "force_opac_sso",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "force_staff_sso",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "autocreate",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "sync",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "welcome",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</shibboleth_config_id>

=back

=cut

__PACKAGE__->set_primary_key("shibboleth_config_id");


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2025-02-21 17:13:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IV80z5JiMbrwFtJKIx6Lmg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
