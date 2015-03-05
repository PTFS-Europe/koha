package Koha::ILLRequest::XML::BLDSS;

# Copyright 2015 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use XML::LibXML;

use base qw(XML::LibXML);

sub load_xml {
    my $self = shift;
    my $doc = $self->SUPER::load_xml(@_);
    my $root = $doc->documentElement;
    return $self->rebless($root);
}

sub rebless {
    my ($self, $node) = @_;
    my $interesting_elements = {
                                apiResponse     => 1,
                                availableFormat => 1,
                                availability    => 1,
                                deliveryFormat  => 1,
                                format          => 1,
                                price           => 1,
                                quality         => 1,
                                result          => 1,
                                service         => 1,
                                speed           => 1,
                                newOrder        => 1,
                               };


    my $name = $node->getName;
    return $node unless ( (ref($node) eq 'XML::LibXML::Element')
                          and (exists(${$interesting_elements}{$name})) );

    my $class_name = $self->element2class($name);
    bless ($node, $class_name);
    return $node;
}

sub element2class {
    my ($self, $class_name) = @_;
    $class_name = ucfirst($class_name);
    $class_name =~ s/-(.?)/uc($1)/e;
    $class_name = "Koha::ILLRequest::XML::BLDSS::$class_name";
}

package Koha::ILLRequest::XML::BLDSS::Element;

use base qw(XML::LibXML::Element);
use vars qw($AUTOLOAD @elements @attributes);

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/^.*::(.*)$/$1/;
    my @elements = $self->elements;
    my @attributes = $self->attributes;
    if (grep (/^$name$/, @elements)) {

        if (my $new_value = $_[0]) {
            my $new_node = XML::LibXML::Element->new($name);
            my $new_text = XML::LibXML::Text->new($new_value);
            $new_node->appendChild($new_text);
            my @kids = $new_node->childNodes;
            if (my ($existing_node) = $self->findnodes("./$name")) {
                $self->replaceChild($new_node, $existing_node);
            } else {
                $self->appendChild($new_node);
            }
        }

        if (my ($existing_node) = $self->findnodes("./$name")) {
            return $existing_node->firstChild->getData;
        } else {
            return '';
        }

    } elsif (grep (/^$name$/, @attributes)) {

        if (my $new_value = $_[0]) {
            $self->setAttribute($name, $new_value);
        }

        return $self->getAttribute($name) || '';

        # I've skipped creator & destructor (p182).
    }
}

# Stubs

sub elements {
    return ();
}

sub attributes {
    return ();
}

# ApiResponse Object

package Koha::ILLRequest::XML::BLDSS::ApiResponse;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw(timestamp status message);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('ApiResponse');
}

sub result {
    my $self = shift;
    my $results = $self->findnodes("./result");
    if (@{$results} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    return Koha::ILLRequest::XML::BLDSS->rebless(${$results}[0]);
}

# Result Object.

package Koha::ILLRequest::XML::BLDSS::Result;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw(currency region copyrightVat loanRenewalCost);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('result');
}

sub availability {
    my $self = shift;
    my $availabilities = $self->findnodes("./availability");
    if (@{$availabilities} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    return Koha::ILLRequest::XML::BLDSS->rebless(${$availabilities}[0]);
}

sub services {
    my $self = shift;
    my @services = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./services/service");
    return  \@services;
}

sub get_service {
    my ($self, $id) = @_;
    unless ($id) {
        die "get_service requires an id!";
    }

    my $services =
      $self->findnodes("./services/service[attribute::id='$id']");
    if (@{$services} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    return Koha::ILLRequest::XML::BLDSS->rebless(${$services}[0]);
}

# Availability Object.

package Koha::ILLRequest::XML::BLDSS::Availability;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw(loanAvailabilityDate copyAvailabilityDate copyrightFee
              availableImmediately matchedToSpecificItem isOnOrder);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('availability');
}

sub formats {
    my $self = shift;
    my @formats = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./availableFormats/availableFormat");
    return \@formats;
}

# AvailableFormat Object.

package Koha::ILLRequest::XML::BLDSS::AvailableFormat;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw(deliveryModifiers);
}

sub attributes {
    return qw(availabilityDate);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('availableFormat');
}

sub deliveryFormat {
    my $self = shift;
    my $formats =
      $self->findnodes("./deliveryFormat");
    if (@{$formats} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    return Koha::ILLRequest::XML::BLDSS->rebless(${$formats}[0]);
}

sub speeds {
    my $self = shift;
    my @speeds = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./availableSpeeds/speed");
    return \@speeds;
}

sub qualities {
    my $self = shift;
    my @qualities = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./availableQuality/quality");
    return \@qualities;
}

# DeliveryFormat Object.

package Koha::ILLRequest::XML::BLDSS::DeliveryFormat;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub attributes {
    return qw(key);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('deliveryFormat');
}

# Speed Object.

package Koha::ILLRequest::XML::BLDSS::Speed;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub attributes {
    return qw(key);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('speed');
}

# Quality Object.

package Koha::ILLRequest::XML::BLDSS::Quality;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub attributes {
    return qw(key);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('quality');
}

# Service Object.

package Koha::ILLRequest::XML::BLDSS::Service;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw();
}

sub attributes {
    return qw(id);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('service');
}

sub formats {
    my $self = shift;
    my @formats = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./format");
    return \@formats;
}

sub get_format {
    my ($self, $id) = @_;
    unless ($id) {
        die "get_format requires an id!";
    }

    my $formats =
      $self->findnodes("./format[attribute::id='$id']");
    if (@{$formats} > 1) {
        warn "We have more than one result.  This should not have happened.";
    }
    return Koha::ILLRequest::XML::BLDSS->rebless(${$formats}[0]);
}

sub prices {
    my $self = shift;
    my @prices = map {Koha::ILLRequest::XML::BLDSS->rebless($_)}
      $self->findnodes("./price");
    return \@prices;
}

# Format Object.

package Koha::ILLRequest::XML::BLDSS::Format;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw();
}

sub attributes {
    return qw(id vat);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('format');
}

# Price Object.

package Koha::ILLRequest::XML::BLDSS::Price;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw();
}

sub attributes {
    return qw(speed quality);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('price');
}

# newOrder Object

package Koha::ILLRequest::XML::BLDSS::NewOrder;

use base qw(Koha::ILLRequest::XML::BLDSS::Element);

sub elements {
    return qw( requestId customerReference service format speed quality
               quantity copyrightState note);
}

sub new {
    my $class = shift;
    return $class->SUPER::new('NewOrder');
}

1;
