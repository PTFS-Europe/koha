package C4::ILL::Config;
use strict;
use warnings;

# Copyright 2013,2014 PTFS Europe Ltd
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

use C4::Context;
our $VERSION = '1.00';

my $_title_fields = {
                     title => { name => "Title" },
                     publisher => { name => "Publisher" },
                     identifier => { name => "ISBN/ISSN/ISMN/Identifier" },
                     author => { name => "Author" },
                     editor => { name => "Editor" },
                     venue => { name => "Venue" },
                     date => { name => "Date" },
                     edition => { name => "Edition" },
                     year => { name => "Year of Publication" },
                     volume => { name => "Volume" },
                    };
my $_item_fields = {
                    year => { name => "Year" },
                    season => { name => "Season" },
                    month => { name => "Month" },
                    day => { name => "Day" },
                    volume => { name => "Volume Number" },
                    part => { name => "Part Number" },
                    issue => { name => "Issue Number" },
                    special => { name => "Special Issue" },
                   };
my $_item_of_interest_fields = {
                                title => { name => "Title" },
                                author => { name => "Author" },
                                pages => { name => "Pages" },
                               };

my $_types =
  {
   journal_article_copy   => {
                              name     => "Journal Article",
                              title    => _tiflds(qw/title publisher identifier/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(qw/title author pages/),
                             },
   journal_part_loan      => {
                              name     => "Journal Loan",
                              title    => _tiflds(qw/title publisher identifier/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(),
                             },
   newspaper_article_copy => {
                              name     => "Newspaper Article",
                              title    => _tiflds(qw/title publisher identifier/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(qw/title author pages/),
                             },
   conference_paper_copy  => {
                              name     => "Conference Paper Copy",
                              title    => _tiflds(qw/title publisher identifier
                                                     editor venue date/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(qw/title author pages/),
                             },
   conference_part_loan   => {
                              name     => "Conference Part Loan",
                              title    => _tiflds(qw/title publisher identifier
                                                     editor venue date/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(),
                             },
   book_copy              => {
                              name     => "Book",
                              title    => _tiflds(qw/title publisher identifier
                                                     author edition year volume/),
                              item     => _itflds(),
                              interest => _inflds(qw/title author pages/),
                             },
   book_loan              => {
                              name     => "Book Loan",
                              title    => _tiflds(qw/title publisher identifier
                                                     author edition year volume/),
                              item     => _itflds(),
                              interest => _inflds(qw/title author pages/),
                             },
   musical_score          => {
                              name     => "Musical Score",
                              title    => _tiflds(qw/title publisher identifier
                                                     author edition year/),
                              item     => _itflds(),
                              interest => _inflds(),
                             },
   default                => {
                              name     => "Default",
                              title    => _tiflds(qw/title publisher identifier year
                                                     volume/),
                              item     => _itflds(qw/year season month day volume
                                                     part issue special/),
                              interest => _inflds(qw/title author pages/),
                             },
  };

sub new {
    my $class = shift;
    my $self  = { };

    bless $self, $class;
    return $self;
}

sub get_types {
    my $self = shift;
    my %_types = %{$_types};
    my %types;
    for my $id ( keys %_types ) {
        $types{$id} = $_types{$id}{name};
    }
    return \%types;
}

sub get_type_details {
    my ($self, $type) = @_;
    return ($type) ? ${$_types}{$type} : 0;
}

sub new_request_status {
    my $self = shift;

    return 'NEW';
}

sub auth_values {
    return get_type_details(@_);
}

# Internal config helpers

sub _select_general_fields {
    my ( $fields, @ids ) = @_;
    my %field_set = %{$fields};
    my %selected_fields;
    for my $id ( @ids ) {
        $selected_fields{$id} = $field_set{$id}
          if ( $field_set{$id} );
    }
    return \%selected_fields;
}

sub _tiflds {
    return _select_general_fields($_title_fields, @_);
}

sub _itflds {
    return _select_general_fields($_item_fields, @_);
}

sub _inflds {
    return _select_general_fields($_item_of_interest_fields, @_);
}

1;
