use utf8;
package Koha::Schema::Result::ShibbolethFieldMapping;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("shibboleth_field_mappings");

__PACKAGE__->add_columns(
  "mapping_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "idp_field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "koha_field",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "is_matchpoint",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("mapping_id");
__PACKAGE__->add_unique_constraint(["idp_field"]);

1;
