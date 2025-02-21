package Koha::Template::Plugin::Shibboleth;

use Modern::Perl;
use base qw(Template::Plugin);

use C4::Context;
use Koha::ShibbolethConfigs;

=head1 NAME

Koha::Template::Plugin::Shibboleth - Shibboleth Template Toolkit plugin

=head1 SYNOPSIS

[% USE Shibboleth %]

[% IF Shibboleth.Config('autocreate') %]
    # Do something when autocreate is enabled
[% END %]

=head1 DESCRIPTION

This plugin provides access to Shibboleth configuration values in templates.

=cut

sub new {
    my ($class, $context) = @_;
    return bless {
        _CONTEXT => $context,
    }, $class;
}

=head2 Config

Returns the value of the specified Shibboleth configuration setting.

@param string $setting The name of the setting to retrieve
@return mixed The value of the setting

=cut

sub Config {
    my ($self, $setting) = @_;
    return Koha::ShibbolethConfigs->get_configuration->get_value($setting);
}

1;
