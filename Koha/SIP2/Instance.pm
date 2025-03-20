# Koha/SIP2/Instance.pm
package Koha::SIP2::Instance;

use strict;
use warnings;

use Koha::Config;
use Koha::Logger;

sub new {
    my ( $class, %params ) = @_;
    my $self = bless {}, $class;
    $self->{name}        = $params{name};
    $self->{config_file} = $params{config_file};
    return $self;
}

sub is_sip_running {
    my ($self) = @_;

    # implement is_sip_running logic here
}

sub is_sip_enabled {
    my ($self) = @_;

    # implement is_sip_enabled logic here
}

sub _check_and_fix_perms {
    my ($self) = @_;

    # implement _check_and_fix_perms logic here
}

1;
