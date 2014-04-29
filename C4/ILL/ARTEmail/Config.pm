package C4::ILL::ARTEmail::Config;

use strict;
use warnings;

=head1 NAME

ILL::ARTEmail::Config - Configuration class for ARTEmail

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

our $service_codes = {
    S      => 'BL Only Search',
    SL     => 'BL and Locations Search',
    BACKUP => 'BL and backup libraries Search',
    SW     => 'BL, Locations and Worldwide Search',
    WWS    => 'Worldwide Search',
};

our $delivery_format_and_speed_codes = {
    SED99  => [ 2,     24, 4 ],
    PTW    => [ 2,     24, 4 ],
    FXBK99 => [ 2,     24, 4 ],
    PHOTO  => [ 2,     24, 4 ],
    LOAN   => [ undef, 24, 4 ],
};

our $other_codes = {
    COPYRT => 'Copyright Fee Paid Service Required',
    WLX    => 'Do not place on waiting list',
};

=head1 SYNOPSIS

Class holds common config settings


=head1 METHODS

=head2 new

Constructor for ILL::ARTEmail::Config

=cut

sub new {
    my $class = shift;
    my $self  = {
        account_id         => '87-0656',
        authorisation_code => 'A1B2C3D',
    };

    bless $self, $class;
    return $self;
}

=head2 account_id

method to return the BL Artel account_id

=cut

sub account_id {
    my $self = shift;
    return $self->{account_id};
}

=head2 authorisation_code

method to return the authorisation code for the artel account

=cut

sub authorisation_code {
    my $self = shift;
    return $self->{authorisation_code};
}

=head1 AUTHOR

Colin Campbell, C<< <colin.campbell at ptfs-europe.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ILL::ARTEmail::Config



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Colin Campbell.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
