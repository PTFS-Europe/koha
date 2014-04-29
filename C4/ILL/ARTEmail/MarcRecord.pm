package C4::ILL::ARTEmail::MarcRecord;
use strict;
use warnings;
use MARC::Record;

=head1 NAME

ILL::ARTEmail::MarcRecord - Class wrapping MARC::Record Object

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Wraps a MARC::Record class adding ArtTel relevant methods

=head1 METHODS

=head2 new

Construct instance around passed MARC::Record

ILL::ARTEmail::MarcRecord->new($MARC_Record_object);

=cut

sub new {
    my ( $class, $marc_rec ) = @_;

    my $self = { marc => $marc_rec, };

    bless $self, $class;
    return $self;
}

=head2 title

returns the title string from the record

=cut

sub title {
    my $self = shift;

    return $self->{marc}->title();
}

=head2 author

returns the author element from the record

=cut

sub author {
    my $self       = shift;
    my $autheditor = $self->{marc}->author();
    if ( !$autheditor ) {
        $autheditor = $self->{marc}->subfield( '700', 'a' );
    }
    return $autheditor;
}

=head2 publisher_place

returns the publisher and place of publication elements from the record

=cut

sub publisher_place {
    my $self  = shift;
    my $pub   = $self->{marc}->subfield( '260', 'b' );
    my $place = $self->{marc}->subfield( '260', 'a' );
    my $str   = join q{ }, $pub, $place;
    return $str;
}

=head1 AUTHOR

Colin Campbell, C<< <colin.campbell at ptfs-europe.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc ILL::ARTEmail::MarcRecord



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Colin Campbell.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
