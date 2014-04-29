package C4::ILL::ARTEmail::Order;

use strict;
use warnings;
use Carp;
use C4::ILL::ARTEmail::Config;
use feature ':5.10';

=head1 NAME

ILL::ARTEmail::Order - Order class for ARTEmail

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Class encapsulates a single Arttel Request Order


=head1 METHODS

=head2 new

Constructor for the Order Class

Should be passed a hash ref containing the relevant parameters

=over

=item config

An already instantiated ILL::ARTEmail::Config instance

=item marc

A MARC::Record object holding the bibn details for the order

=item order_address

A Delivery address specific to this order should be passed as a reference
to an array of address lines

=item address_type

Can be email or postal defaults to postal
Used in formatting the order_address if email is specified it assumes
that the first line contains the email address

=back

=cut

sub new {
    my ( $class, $arg_ref ) = @_;

    if ( ref $arg_ref ne 'HASH' ) {
        carp "constructor for $class called without parameters";
        $arg_ref = { request_type => 'book', };    # default
    }
    my $self = _init($arg_ref);

    bless $self, $class;
    return $self;
}

=head2 output

produces the order in a format for inclusion in
an ARTel message

=cut

sub output {
    my $self = shift;
    my @tx_params;
    if ( $self->{reference_number} ) {
        push @tx_params, $self->{reference_number};
    }
    if ( $self->{keyword_codes} ) {
        push @tx_params, @{ $self->{keyword_codes} };
    }

    my $text = _tx_line();
    my @lines;
    given ( $self->{request_type} ) {
        when (/^article/) {
            @lines = $self->_format_article();
        }
        when (/^book/) {
            @lines = $self->_format_book();
        }
        when (/^paper/) {
            @lines = $self->_format_paper();
        }
    }

    for my $line (@lines) {
        if ($line) {
            $text .= substr( $line, 0, 40 );
            $text .= "\n";
        }
    }
    if ( $self->{order_address} ) {
        $text .= "\n\n\n\n:DELIVER ABOVE ITEM TO:\n";
        if ( $self->{address_type} eq 'postal' ) {
            my $line_count = 0;
            for my $line ( @{ $self->{order_address} } ) {
                chomp $line;
                if ($line) {
                    $text .= substr( $line, 0, 40 );
                    $text .= "\n";
                    if ( ++$line_count == 6 ) {
                        last;
                    }

                }
            }
        }
        lse {    #email single line
            chomp $self->{order_address}->[0];
            $text .= $self->{order_address}->[0];
            $text .= "\n";

        }
    }
    return $text;
}

=head2 set_keyword_codes

Setter to set one or more keyword codes
Alternatively they can be passed as an
arrayref keyword_codes in initialization

=cut

sub set_keyword_codes {
    my ( $self, @codes ) = @_;
    if (@codes) {
        $self->{keyword_codes} = \@codes;
    }
    return;
}

sub _format_article {
    my $self = shift;
    my ( $vol, $part, $pages );
    if ( $self->{volume} ) {
        $vol = 'VOL ' . $self->{volume};
    }
    if ( $self->{part} ) {
        $part = 'PT ' . $self->{part};
    }
    if ( $self->{pages} ) {
        $pages = 'PP ' . $self->{pages};
    }
    my $year_vol_etc = join q{ }, $self->{year}, $vol, $part, $pages;
    my $title = join q{ }, $self->{article_title}, $self->{article_author};
    my $issn  = join q{ }, $self->{issn},          $self->{shelfmark};

    return ( $self->{journal_title}, $year_vol_etc, $title, $issn );
}

sub _format_book {
    my $self = shift;
    my $pp = join q{ }, $self->{publisher}, $self->{place_publication};
    my ( $vol, $part );
    if ( $self->{volume} ) {
        $vol = 'VOL ' . $self->{volume};
    }
    if ( $self->{part} ) {
        $part = 'PT ' . $self->{part};
    }
    my $y = join q{ }, $self->{year}, $vol, $part, $self->{edition};
    my $isbn = join q{ }, $self->{isbn}, $self->{shelfmark};
    return ( $self->{title}, $self->{author_editor}, $pp, $y, $isbn );
}

sub _format_paper {
    my $self = shift;
    my ( $vol, $part, $pages );
    if ( $self->{volume} ) {
        $vol = 'VOL ' . $self->{volume};
    }
    if ( $self->{part} ) {
        $part = 'PT ' . $self->{part};
    }
    if ( $self->{pages} ) {
        $pages = 'PP ' . $self->{pages};
    }
    my $year_vol_etc = join q{ }, $self->{year}, $vol, $part, $pages;
    my $when_where = join q{ ,}, $self->{date}, $self->{venue},
      $self->{sponsor};
    my $title = join q{ }, $self->{paper_title}, $self->{paper_author};
    my $isbn  = join q{ }, $self->{isbn},        $self->{shelfmark};

    return ( $self->{conference_title}, $when_where, $year_vol_etc, $title,
        $isbn );
}

sub _init {
    my $arg_ref = shift;
    my $self    = {};
    if ( $arg_ref->{config}
        && ( ref $arg_ref->{config} eq 'C4::ILL::ARTEmail::Config' ) )
    {
        $self->{cfg} = $arg_ref->{config};
    }
    else {
        $self->{cfg} = C4::ILL::ARTEmail::Config->new();
    }

    # Not Implemented
    #if ( $arg_ref->{marc} && ( ref $arg_ref->{marc} eq 'MARC::Record' ) ) {
    #     $self->{marc} = ILL::ARTEmail::MarcRec->new( $arg_ref->{marc} );
    #}

    if ( $arg_ref->{request_type} ) {
        $self->{request_type} = lc $arg_ref->{request_type};
    }
    if ( $self->{request_type} !~ m/(article|book|paper)/ ) {
        croak("Request Type must bw article, book or paper");
    }
    if ( $arg_ref->{order_address} ) {
        $self->{order_address} = $arg_ref->{order_address};
        if ( $arg_ref->{address_type} ) {
            $self->{address_type} = $arg_ref->{address_type};
        }
        if ( !$self->{address_type} || $self->{address_type} ne 'email' ) {
            $self->{address_type} = 'postal';
        }
    }
    for my $key (
        qw( journal_title year volume part pages article_title article_author
        issn shelfmark book_title author_editor publisher place_publication edition
        isbn conference_title paper_title paper_author date venue sponsor
        reference_number keyword_codes)
      )
    {
        if ( $arg_ref->{$key} ) {
            $self->{$key} = $arg_ref->{$key};
        }
    }

    return $self;
}

sub _tx_line {
    my ( $refnum, @message_keyword_codes ) = @_;
    my $tx = 'TX';
    if ($refnum) {
        $tx .= $refnum;
    }
    my $tx_line = join q{ }, ( $tx, @message_keyword_codes );
    $tx_line .= "\n";
    return $tx_line;
}

sub _fields_from_marc {
    my $mrec = shift;

    # get the request elements from the marc bib rec
    return;
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
