package Koha::ILL;

# Copyright PTFS Europe 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;

use Koha::ILL::Config;
use Koha::ILL::Service;
use Koha::ILL::Requests;

=head1 NAME

Koha::ILL - Koha ILL Object Class

=head1 SYNOPSIS

use Koha::ILL;

my $bldss = Koha::ILL->new($service);

=head1 API

=head2 Class Methods

=cut

# New, Initialises object (with config if given)
=head3 new

=cut

sub new {
    my ( $class, $service ) = @_;
    my $self = {};
    ${$self}{config} = Koha::ILL::Config->new();

    bless( $self, $class );

    return $self;
}

# Config, returns config hashref (and allows manipulation of config if passed)
=head3 config

=cut

sub config {
    my ( $self ) = @_;

    return ${$self}{config};
}

=head3 Requests

my $request = $bldss->Requests( { id => $id } );

=cut

sub Requests {
    my ( $self, $filter ) = @_;

    $self->{Requests} ||= Koha::ILL::Requests->new()->search( $filter );

    return $self->{Requests};
}

=head3 Recoed

my $record = $bldss->Record();

=cut

sub Record {
    my ( $self, $filter ) = @_;

    $self->{Record} ||= Koha::ILL::Record->new(${$self}{config});

    return $self->{Record};
}

=head3 Service

my $service = $blds->Service();

=cut

sub Service {
    my ( $self ) = @_;

    $self->{Service} ||= Koha::ILL::Service->new( ${$self}{config} );

    return $self->{Service};
}

1;
