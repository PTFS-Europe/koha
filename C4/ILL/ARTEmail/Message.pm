package C4::ILL::ARTEmail::Message;

use strict;
use warnings;
use C4::ILL::ARTEmail::Config;

=head1 NAME

ILL::ARTEmail::Message - Message class for ARTEmail

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Class outputs ARTEmail formatted requests


=head1 METHODS

=head2 new

Constructor for the Message Class

=cut

sub new {
    my ( $class, @orders ) = @_;
    my $self = {};
    $self->{cfg}    = C4::ILL::ARTEmail::Config->new();
    $self->{orders} = \@orders;

    bless $self, $class;
    return $self;
}

=head2 output

produces the artel message containing all orders

=cut

sub output {
    my $self = shift;

    my $four_blank_lines = "\n" x 4;
    my $text = join "\n", $self->{cfg}->account_id(),
      $self->{cfg}->authorisation_code();
    $text .= "\n$four_blank_lines";

    for my $ord ( @{ $self->{orders} } ) {
        $text .= $ord->output();
        $text .= $four_blank_lines;
    }
    $text .= "NNNN\n";
    return $text;
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
