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
  extra: {list => ["ftp","sftp"]}
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

  data_type: 'mediumtext'
  is_nullable: 1

=head2 key_file

  data_type: 'mediumtext'
  is_nullable: 1

=head2 auth_mode

  data_type: 'enum'
  default_value: 'password'
  extra: {list => ["password","key_file","noauth"]}
  is_nullable: 0

=head2 download_directory

  data_type: 'mediumtext'
  is_nullable: 1

=head2 upload_directory

  data_type: 'mediumtext'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

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
    extra => { list => ["ftp", "sftp"] },
    is_nullable => 0,
  },
  "passiv",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "user_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "password",
  { data_type => "mediumtext", is_nullable => 1 },
  "key_file",
  { data_type => "mediumtext", is_nullable => 1 },
  "auth_mode",
  {
    data_type => "enum",
    default_value => "password",
    extra => { list => ["password", "key_file", "noauth"] },
    is_nullable => 0,
  },
  "download_directory",
  { data_type => "mediumtext", is_nullable => 1 },
  "upload_directory",
  { data_type => "mediumtext", is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
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

=head2 vendor_edi_accounts_download_sftp_servers

Type: has_many

Related object: L<Koha::Schema::Result::VendorEdiAccount>

=cut

__PACKAGE__->has_many(
  "vendor_edi_accounts_download_sftp_servers",
  "Koha::Schema::Result::VendorEdiAccount",
  { "foreign.download_sftp_server_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vendor_edi_accounts_upload_sftp_servers

Type: has_many

Related object: L<Koha::Schema::Result::VendorEdiAccount>

=cut

__PACKAGE__->has_many(
  "vendor_edi_accounts_upload_sftp_servers",
  "Koha::Schema::Result::VendorEdiAccount",
  { "foreign.upload_sftp_server_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2024-12-17 16:16:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UNNFdqDr0NgEGaYlWJs49w

__PACKAGE__->add_columns(
    '+passiv'     => { is_boolean => 1 },
    '+debug'      => { is_boolean => 1 },
);

sub koha_objects_class {
    'Koha::SFTP::Servers';
}

sub koha_object_class {
    'Koha::SFTP::Server';
}

1;
