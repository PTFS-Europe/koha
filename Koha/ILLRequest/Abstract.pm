package Koha::ILLRequest::Abstract;

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
use XML::LibXML;
use C4::Branch;
use Koha::ILLRequest::XML::BLDSS;
use Koha::ILLRequest::Record;
use Koha::ILLRequest::Status;
use Koha::ILLRequest::Config;

=head1 NAME

Koha::ILLRequest::Abstract - Koha ILL AbstractILL Object class

=head1 SYNOPSIS

=head1 DESCRIPTION

In theory, this class is to act as a layer in between individual means for
communicating with ILL APIs and other objects.

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
    $self->{api} = BLDSS->new( $creds );

    bless( $self, $class );
    return $self;
}

=head3 _getStatusCode

    my $illStatus = _getStatusCode($status, $message);

An introspective call turning API error codes into ILL Module error codes.

=cut

sub _getStatusCode {
    my ( $status, $message ) = @_;
    my $code = "This unusual case has not yet been defined: $message ($status)";
    if ( '111' eq $status ) {
        $code = 'unavailable';
    } elsif ( '1' eq $status ) {
        if ( 'Invalid Request: A valid physical address is required for the delivery format specified' eq $message ) {
            $code = 'branch_address_incomplete';
        }
    }
    return $code;
}

=head3 _api

    my $api = $abstract->api( $params );

Perform an action on $self's API object. if !$PARAMS, return the object.
Else, perform the API operation in $params->{action}, with the action params
in $params->{params}, and evaluate it's result in API.

Die if the API reports an error.

=cut

sub _api {
    my ( $self, $params ) = @_;

    return $self->{api}
        if ( !$params or !$params->{action} );

    my $op = $params->{action};
    my $re;
    if      ( 'availability' eq $op ) {
        $re = $self->_api->availability(@{$params->{params}});
    } elsif ( 'create_order' eq $op ) {
        $re = $self->_api->create_order(@{$params->{params}});
    } elsif ( 'cancel_order' eq $op ) {
        $re = $self->_api->cancel_order(@{$params->{params}});
    } elsif ( 'prices' eq $op ) {
        $re = $self->_api->prices(@{$params->{params}});
    } elsif ( 'search' eq $op ) {
        $re = $self->_api->search(@{$params->{params}});
        return $re;
    }

    die(
        "The API responded with an error: ", $self->_api->error->{status},
        "\nDetail: ", $self->_api->error->{content}
    ) if ( $self->_api->error );

    $re = Koha::ILLRequest::XML::BLDSS->new->load_xml( { string => $re } );
    return _getStatusCode($re->status, $re->message)
        if ( $re->status ne '0' );
    return $re;
}


sub build {
    my ( $self, $attributes ) = @_;

    my $record = Koha::ILLRequest::Record->new($self->{config})
      ->create_from_store($attributes);
    my $status = Koha::ILLRequest::Status->new->create_from_store($attributes);

    return { record => $record, status => $status };
}

=head3 checkAvailability

    my $availability = $abstract->checkAvailability($uin, $properties);

Submit a request to the currently configured API for $UIN, supplemented with
the hashref $PROPERTIES.  Return the API response as an HTML object.

=cut

sub checkAvailability {
    my ( $self, $record ) = @_;
    my $reply  = $self->_api( {
        action => 'availability',
        params => [
            $record->getProperty('id'),
            { year => $record->getProperty('year') } ]
    } );

    return $reply;
}

=head3 getPrices

    my $getPrices = $abstract->getPrices;

Return an array containing pricing information for the API in use.

=cut

sub getPrices {
    my ( $self ) = @_;

    my $prices = $self->_api( {
        action => 'prices',
        params => [],
    } );

    return $prices;
}

=head3 getLimits

    my $limit_rules = $abstract->getLimits( {
        type  => 'brw_cat' | 'branch',
        value => $value
    } );

Return the ILL limit rules for the supplied combination of type / value.

As the config may have no rules for this particular type / value combination,
or for the default, we must define fall-back values here.

=cut

sub getLimits {
    my ( $self, $params ) = @_;
    my $limits = $self->{config}->getLimitRules($params->{type});

    return $limits->{$params->{value}}
        || $limits->{default}
        || { count => -1, method => 'active' };
}

=head3 getDefaultFormat

    my $format = $abstract->getDefaultFormat( {
        brw_cat => $brw_cat,
        branch  => $branch_code,
    } );

Return the ILL default format that we should use in case of non-interactive
use.  We will return borrower category definitions with a higher priority than
branch level definitions.  Default is fall-back.

This procedure just dies if it cannot find a sane values, as we assume the
caller requires configured defaults.

=cut

sub getDefaultFormat {
    my ( $self, $params ) = @_;
    my $brn_formats = $self->{config}->getDefaultFormats('branch');
    my $brw_formats = $self->{config}->getDefaultFormats('brw_cat');

    return $brw_formats->{$params->{brw_cat}}
        || $brn_formats->{$params->{branch}}
        || $brw_formats->{default}
        || die "No suitable format found.  Unlikely to have happened.";
}

=head3 request

    my $result = $abstract->request($params);

Return confirmation of whether we were able to place the request defined by
$PARAMS with the API.

=cut

sub request {
    my ( $self, $params ) = @_;

    my $brw = $params->{patron};
    my $branch = C4::Branch::GetBranchDetail($params->{branch});
    # Currently hard-coded to BL requirements.  This should instead use
    # methods from the API or config to extract appropriate & required fields.
    my $final_details = {
        type     => "A",
        Item     => {
            uin      => $params->{record}->getProperty('id'),
        },
        service  => $params->{transaction},
        Delivery => {
            email   => $branch->{branchemail} || "",
            Address => {
                AddressLine1     => $branch->{branchaddress1} || "",
                AddressLine2     => $branch->{branchaddress2} || "",
                AddressLine3     => $branch->{branchaddress3} || "",
                TownOrCity       => $branch->{branchcity} || "",
                CountyOrState    => $branch->{branchstate} || "",
                ProvinceOrRegion => "",
                PostOrZipCode    => $branch->{branchzip} || "",
                Country          => $branch->{branchcountry} || "",
            }
        },
        # Optional params:
        requestor         => join(" ", $brw->firstname, $brw->surname),
        # FIXME: we'll need to add prefix here
        customerReference => $params->{reference},
    };
    my $rq_result = $self->_api( {
        action => 'create_order',
        params => [ $final_details ],
    } );

    return $rq_result;
}

=head3 search

    my $results = $abstractILL->search($query);

Return an array of Record objects created from this AbstractILL's config and
the output of querying the API in use.

The optional OPTS parameter specifies additional options to be passed to the
API. For now the options we use in the ILL Module are:
 max_results -> SearchRequest.maxResults,
 start_rec   -> SearchRequest.start,
 isbn        -> SearchRequest.Advanced.isbn
 issn        -> SearchRequest.Advanced.issn
 title       -> SearchRequest.Advanced.title
 author      -> SearchRequest.Advanced.author
 type        -> SearchRequest.Advanced.type
 general     -> SearchRequest.Advanced.general

We simply pass the options hashref straight to the API library.

=cut

sub search {
    my ( $self, $query, $opts ) = @_;

    my $reply = $self->_api( {
        action => 'search',
        params => [ $query, $opts ],
    } );

    my $parser = XML::LibXML->new;
    my $doc = $parser->load_xml( { string => $reply } );

    my @return;
    foreach my $datum ( $doc->findnodes('/apiResponse/result/records/record') ) {
        my $record =
          Koha::ILLRequest::Record->new($self->{config})
            ->create_from_xml($datum);
        push (@return, $record);
    }

    return \@return;
}

=head1 AUTHOR

Alex Sassmannshausen <alex.sassmannshausen@ptfs-europe.com>

=cut

1;
