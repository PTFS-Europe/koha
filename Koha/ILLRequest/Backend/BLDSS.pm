package Koha::ILLRequest::Backend::BLDSS;

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

use BLDSS;
use Locale::Country;
use XML::LibXML;
use Koha::ILLRequest::Config;

# We will be implementing the Abstract interface.
#use base qw(Koha::ILLRequest::Abstract);

=head1 NAME

Koha::ILLRequest::BLDSS - Koha ILL Backend: BLDSS

=head1 SYNOPSIS

=head1 DESCRIPTION

A first stub file to help to split out BLDSS specific logic from the Abstract
ILL Interface.

=head1 API

=head2 Class Methods

=cut

=head3 new

=cut

sub new {
    my ( $class, $params ) = @_;
    my $self = {};

    # This is where we may want to introduce the possibility to choose amongst
    # backends.
    $self->{config} = Koha::ILLRequest::Config->new;
    my $creds = $self->{config}->getCredentials($params->{branch});
    # use Data::Dump qw(dump);
    # die dump $creds;
    $self->{api} = BLDSS->new( $creds );

    bless( $self, $class );
    return $self;
}

sub validate_delivery_input {
    my ( $self, $params ) = @_;
    my ( $fmt, $brw, $brn, $recipient ) = (
        $params->{service}->{format}, $params->{borrower}, $params->{branch},
        $params->{digital_recipient},
    );
    # FIXME: Here we can cross-reference services with API's services request.
    # The latter currently returns 404, so instead we mock a services
    # response.
    # my $formats = $self->_api_do( {
    #     action => 'reference',
    #     params => [ 'formats' ],
    # } );
    my $formats = {
        1 => "digital",
        2 => "digital",
        3 => "digital",
        4 => "physical",
        5 => "physical",
        6 => "physical",
    };
    # Seed return values.
    # FIXME: instead of dying we should return Status, for friendly UI output
    # (0 only in case of all valid).
    my ( $status, $delivery ) = ( 0, {} );

    if ( 'digital' eq $formats->{$fmt} ) {
        my $target = $brw->email || "";
        $target = $brn->{branchemail} if ( 'branch' eq $recipient );
        die "Digital delivery: invalid $recipient type email address."
            if ( !$target );
        $delivery->{email} = $target;
    } elsif ( 'physical' eq $formats->{$fmt} ) {
        # Country
        $delivery->{Address}->{Country} = country2code(
            $brn->{branchcountry}, LOCALE_CODE_ALPHA_3
        ) || die "Invalid country in branch record: $brn->{branchcountry}.";
        # Mandatory Fields
        my $mandatory_fields = {
            AddressLine1  => "branchaddress1",
            AddressLine2  => "branchaddress2",
            TownOrCity    => "branchcity",
            PostOrZipCode => "branchzip",
        };
        while ( my ( $bl_field, $k_field ) = each %{$mandatory_fields} ) {
            die "Physical delivery requested, but branch missing $k_field."
                if ( !$brn->{$k_field} or "" eq $brn->{$k_field} );
            $delivery->{Address}->{$bl_field} = $brn->{$k_field};
        }
        # Optional Fields
        my $optional_fields = {
            AddressLine3     => "branchaddress3",
            CountyOrState    => "branchstate",
            ProvinceOrRegion => "",
        };
        while ( my ( $bl_field, $k_field ) = each %{$optional_fields} ) {
            $delivery->{Address}->{$bl_field} = $brn->{$k_field} || "";
        }
    } else {
        die "Unknown service type: $fmt."
    }

    return ( $status, $delivery );
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
