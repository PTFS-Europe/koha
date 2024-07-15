use utf8;
package Koha::Schema::Result::Category;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Category

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<categories>

=cut

__PACKAGE__->table("categories");

=head1 ACCESSORS

=head2 categorycode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

unique primary key used to idenfity the patron category

=head2 description

  data_type: 'longtext'
  is_nullable: 1

description of the patron category

=head2 enrolmentperiod

  data_type: 'smallint'
  is_nullable: 1

number of months the patron is enrolled for (will be NULL if enrolmentperioddate is set)

=head2 enrolmentperioddate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

date the patron is enrolled until (will be NULL if enrolmentperiod is set)

=head2 password_expiry_days

  data_type: 'smallint'
  is_nullable: 1

number of days after which the patron must reset their password

=head2 upperagelimit

  data_type: 'smallint'
  is_nullable: 1

age limit for the patron

=head2 dateofbirthrequired

  data_type: 'tinyint'
  is_nullable: 1

the minimum age required for the patron category

=head2 finetype

  data_type: 'varchar'
  is_nullable: 1
  size: 30

unused in Koha

=head2 bulk

  data_type: 'tinyint'
  is_nullable: 1

=head2 enrolmentfee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

enrollment fee for the patron

=head2 overduenoticerequired

  data_type: 'tinyint'
  is_nullable: 1

are overdue notices sent to this patron category (1 for yes, 0 for no)

=head2 issuelimit

  data_type: 'smallint'
  is_nullable: 1

unused in Koha

=head2 reservefee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

cost to place holds

=head2 hidelostitems

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

are lost items shown to this category (1 for yes, 0 for no)

=head2 category_type

  data_type: 'varchar'
  default_value: 'A'
  is_nullable: 0
  size: 1

type of Koha patron (Adult, Child, Professional, Organizational, Statistical, Staff)

=head2 BlockExpiredPatronOpacActions

  accessor: 'block_expired_patron_opac_actions'
  data_type: 'mediumtext'
  default_value: ''follow_syspref_BlockExpiredPatronOpacActions''
  is_nullable: 0

specific actions expired patrons of this category are blocked from performing or if the BlockExpiredPatronOpacActions system preference is to be followed

=head2 default_privacy

  data_type: 'enum'
  default_value: 'default'
  extra: {list => ["default","never","forever"]}
  is_nullable: 0

Default privacy setting for this patron category

=head2 checkprevcheckout

  data_type: 'varchar'
  default_value: 'inherit'
  is_nullable: 0
  size: 7

produce a warning for this patron category if this item has previously been checked out to this patron if 'yes', not if 'no', defer to syspref setting if 'inherit'.

=head2 can_place_ill_in_opac

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

can this patron category place interlibrary loan requests

=head2 can_be_guarantee

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

if patrons of this category can be guarantees

=head2 reset_password

  data_type: 'tinyint'
  is_nullable: 1

if patrons of this category can do the password reset flow,

=head2 change_password

  data_type: 'tinyint'
  is_nullable: 1

if patrons of this category can change their passwords in the OAPC

=head2 min_password_length

  data_type: 'smallint'
  is_nullable: 1

set minimum password length for patrons in this category

=head2 require_strong_password

  data_type: 'tinyint'
  is_nullable: 1

set required password strength for patrons in this category

=head2 exclude_from_local_holds_priority

  data_type: 'tinyint'
  is_nullable: 1

Exclude patrons of this category from local holds priority

=head2 noissuescharge

  data_type: 'integer'
  is_nullable: 1

define maximum amount withstanding before checkouts are blocked

=head2 noissueschargeguarantees

  data_type: 'integer'
  is_nullable: 1

define maximum amount withstanding before checkouts are blocked

=head2 noissueschargeguarantorswithguarantees

  data_type: 'integer'
  is_nullable: 1

define maximum amount withstanding before checkouts are blocked

=cut

__PACKAGE__->add_columns(
  "categorycode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "description",
  { data_type => "longtext", is_nullable => 1 },
  "enrolmentperiod",
  { data_type => "smallint", is_nullable => 1 },
  "enrolmentperioddate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "password_expiry_days",
  { data_type => "smallint", is_nullable => 1 },
  "upperagelimit",
  { data_type => "smallint", is_nullable => 1 },
  "dateofbirthrequired",
  { data_type => "tinyint", is_nullable => 1 },
  "finetype",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "bulk",
  { data_type => "tinyint", is_nullable => 1 },
  "enrolmentfee",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "overduenoticerequired",
  { data_type => "tinyint", is_nullable => 1 },
  "issuelimit",
  { data_type => "smallint", is_nullable => 1 },
  "reservefee",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "hidelostitems",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "category_type",
  { data_type => "varchar", default_value => "A", is_nullable => 0, size => 1 },
  "BlockExpiredPatronOpacActions",
  {
    accessor      => "block_expired_patron_opac_actions",
    data_type     => "mediumtext",
    default_value => "'follow_syspref_BlockExpiredPatronOpacActions'",
    is_nullable   => 0,
  },
  "default_privacy",
  {
    data_type => "enum",
    default_value => "default",
    extra => { list => ["default", "never", "forever"] },
    is_nullable => 0,
  },
  "checkprevcheckout",
  {
    data_type => "varchar",
    default_value => "inherit",
    is_nullable => 0,
    size => 7,
  },
  "can_place_ill_in_opac",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "can_be_guarantee",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "reset_password",
  { data_type => "tinyint", is_nullable => 1 },
  "change_password",
  { data_type => "tinyint", is_nullable => 1 },
  "min_password_length",
  { data_type => "smallint", is_nullable => 1 },
  "require_strong_password",
  { data_type => "tinyint", is_nullable => 1 },
  "exclude_from_local_holds_priority",
  { data_type => "tinyint", is_nullable => 1 },
  "noissuescharge",
  { data_type => "integer", is_nullable => 1 },
  "noissueschargeguarantees",
  { data_type => "integer", is_nullable => 1 },
  "noissueschargeguarantorswithguarantees",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</categorycode>

=back

=cut

__PACKAGE__->set_primary_key("categorycode");

=head1 RELATIONS

=head2 borrower_attribute_types

Type: has_many

Related object: L<Koha::Schema::Result::BorrowerAttributeType>

=cut

__PACKAGE__->has_many(
  "borrower_attribute_types",
  "Koha::Schema::Result::BorrowerAttributeType",
  { "foreign.category_code" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 borrower_message_preferences

Type: has_many

Related object: L<Koha::Schema::Result::BorrowerMessagePreference>

=cut

__PACKAGE__->has_many(
  "borrower_message_preferences",
  "Koha::Schema::Result::BorrowerMessagePreference",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 borrowers

Type: has_many

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->has_many(
  "borrowers",
  "Koha::Schema::Result::Borrower",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 categories_branches

Type: has_many

Related object: L<Koha::Schema::Result::CategoriesBranch>

=cut

__PACKAGE__->has_many(
  "categories_branches",
  "Koha::Schema::Result::CategoriesBranch",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 circulation_rules

Type: has_many

Related object: L<Koha::Schema::Result::CirculationRule>

=cut

__PACKAGE__->has_many(
  "circulation_rules",
  "Koha::Schema::Result::CirculationRule",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 identity_provider_domains

Type: has_many

Related object: L<Koha::Schema::Result::IdentityProviderDomain>

=cut

__PACKAGE__->has_many(
  "identity_provider_domains",
  "Koha::Schema::Result::IdentityProviderDomain",
  { "foreign.default_category_id" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2024-03-26 17:00:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6I6SD78A/PJ0AhUc1IEOPg

sub koha_object_class {
    'Koha::Patron::Category';
}
sub koha_objects_class {
    'Koha::Patron::Categories';
}

__PACKAGE__->add_columns(
    '+can_be_guarantee'                  => { is_boolean => 1 },
    '+can_place_ill_in_opac'             => { is_boolean => 1 },
    '+exclude_from_local_holds_priority' => { is_boolean => 1 },
    '+require_strong_password'           => { is_boolean => 1 },
);

1;
