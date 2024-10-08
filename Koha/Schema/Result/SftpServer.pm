use utf8;
package Koha::Schema::Result::SftpServer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::SftpServer

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sftp_servers>

=cut

__PACKAGE__->table("sftp_servers");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 host

  data_type: 'varchar'
  default_value: 'localhost'
  is_nullable: 0
  size: 80

=head2 port

  data_type: 'integer'
  default_value: 22
  is_nullable: 0

=head2 transport

  data_type: 'enum'
  default_value: 'sftp'
  extra: {list => ["ftp","sftp","file"]}
  is_nullable: 0

=head2 passiv

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 user_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 key_file

  data_type: 'varchar'
  is_nullable: 1
  size: 4096

=head2 auth_mode

  data_type: 'enum'
  default_value: 'password'
  extra: {list => ["password","key_file","noauth"]}
  is_nullable: 0

=head2 debug

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "host",
  {
    data_type => "varchar",
    default_value => "localhost",
    is_nullable => 0,
    size => 80,
  },
  "port",
  { data_type => "integer", default_value => 22, is_nullable => 0 },
  "transport",
  {
    data_type => "enum",
    default_value => "sftp",
    extra => { list => ["ftp", "sftp", "file"] },
    is_nullable => 0,
  },
  "passiv",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "user_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "key_file",
  { data_type => "varchar", is_nullable => 1, size => 4096 },
  "auth_mode",
  {
    data_type => "enum",
    default_value => "password",
    extra => { list => ["password", "key_file", "noauth"] },
    is_nullable => 0,
  },
  "debug",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 vendor_edi_accounts

Type: has_many

Related object: L<Koha::Schema::Result::VendorEdiAccount>

=cut

__PACKAGE__->has_many(
  "vendor_edi_accounts",
  "Koha::Schema::Result::VendorEdiAccount",
  { "foreign.sftp_server_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2024-10-16 09:01:20
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LV/voK/j3DzE3wpY0uul3A

__PACKAGE__->add_columns(
    '+debug'      => { is_boolean => 1 },
);

sub koha_objects_class {
    'Koha::SFTP::Servers';
}

sub koha_object_class {
    'Koha::SFTP::Server';
}

1;
