package C4::Message;

# Copyright Liblime 2009
# Copyright Catalyst IT 2012
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


use strict;
use warnings;
use C4::Context;
use C4::Letters qw( GetPreparedLetter EnqueueLetter );
use YAML::XS qw( Dump );
use Encode;
use Carp qw( carp );

=head1 NAME

C4::Message - object for messages in the message_queue table

=head1 SYNOPSIS

How to add a new message to the queue:

  use C4::Message;
  use C4::Items;
  my $borrower = { borrowernumber => 1 };
  my $item     = Koha::Items->find($itemnumber)->unblessed;
  my $letter =  C4::Letters::GetPreparedLetter (
      module => 'circulation',
      letter_code => 'CHECKOUT',
      branchcode => $branch,
      tables => {
          'biblio', $item->{biblionumber},
          'biblioitems', $item->{biblionumber},
      },
  );
  C4::Message->enqueue($letter, $borrower->{borrowernumber}, 'email');

How to update a borrower's last checkout message:

  use C4::Message;
  my $borrower = { borrowernumber => 1 };
  my $message  = C4::Message->find_last_message($borrower, 'CHECKOUT', 'email');
  $message->append("you also checked out some other book....");
  $message->update;

=head1 DESCRIPTION

This module presents an OO interface to the message_queue.  Previously, 
you could only add messages to the message_queue via 
C<C4::Letters::EnqueueMessage()>.  With this module, you can also get 
previously inserted messages, manipulate them, and save them back to the 
database.

=cut


our $AUTOLOAD;


=head2 Class Methods

=head3 C4::Message->new(\%attributes)

This method creates an in-memory version of a message object.

=cut

# C4::Message->new(\%attributes) -- constructor
sub new {
    my ($class, $opts) = @_;
    $opts ||= {};
    bless {%$opts} => $class;
}


=head3 C4::Message->find($id)

This method searches the message_queue table for a row with the given
C<message_id> and it'll return a C4::Message object if it finds one.

=cut

# C4::Message->find($id) -- find a message by its message_id
sub find {
    my ($class, $id) = @_;
    my $dbh = C4::Context->dbh;
    my $msgs = $dbh->selectall_arrayref(
        qq{SELECT * FROM message_queue WHERE message_id = ?},
        { Slice => {} },
        $id,
    );
    if (@$msgs) {
        return $class->new($msgs->[0]);
    } else {
        return;
    }
}

=head3 C4::Message->find_last_message($borrower, $letter_code, $transport)

This method is used to get the borrower's most recent, pending, check-in or
checkout message.  (This makes it possible to add more information to the
message before it gets sent out.)

=cut

# C4::Message->find_last_message($borrower, $letter_code, $transport)
# -- get the borrower's most recent pending checkin or checkout notification
sub find_last_message {
    my ($class, $borrower, $letter_code, $transport) = @_;
    # $type is the message_transport_type
    $transport ||= 'email';
    my $dbh = C4::Context->dbh;
    my $msgs = $dbh->selectall_arrayref(
        qq{
            SELECT *
            FROM   message_queue
            WHERE  status                 = 'pending'
            AND    borrowernumber         = ?
            AND    letter_code            = ?
            AND    message_transport_type = ?
        },
        { Slice => {} },
        $borrower->{borrowernumber},
        $letter_code,
        $transport,
    );
    if (@$msgs) {
        return $class->new($msgs->[0]);
    } else {
        return;
    }
}


=head3 C4::Message->enqueue($letter, $borrower, $transport)

This is a front-end for C<C4::Letters::EnqueueLetter()> that adds metadata to
the message.

=cut

# C4::Message->enqueue($letter, $borrower, $transport)
sub enqueue {
    my ($class, $letter, $borrower, $transport) = @_;
    my $metadata   = _metadata($letter);
    my $to_address = _to_address($borrower, $transport);

    # Same as render_metadata
    my $format ||= sub { $_[0] || "" };
    my $body = join('', map { $format->($_) } @{$metadata->{body}});
    $letter->{content} = $metadata->{header} . $body . $metadata->{footer};

    $letter->{metadata} = Encode::decode_utf8(Dump($metadata));
    C4::Letters::EnqueueLetter({
        letter                 => $letter,
        borrowernumber         => $borrower->{borrowernumber},
        message_transport_type => $transport,
        to_address             => $to_address,
    });
}

# based on message $transport, pick an appropriate address to send to
sub _to_address {
    my ($borrower, $transport) = @_;
    my $address;
    if ($transport eq 'email') {
        $address = $borrower->{email}
            || $borrower->{emailpro}
            || $borrower->{B_email};
    } elsif ($transport eq 'sms') {
        $address = $borrower->{smsalertnumber};
    } else {
        warn "'$transport' is an unknown message transport.";
    }
    if (not defined $address) {
        warn "An appropriate $transport address "
            . "for borrower $borrower->{userid} "
            . "could not be found.";
    }
    return $address;
}

# _metadata($letter) -- return the letter split into head/body/footer
sub _metadata {
    my ($letter) = @_;
    if ($letter->{content} =~ /----/) {
        my ($header, $body, $footer) = split(/----\r?\n?/, $letter->{content});
        return {
            header => $header,
            body   => [$body],
            footer => $footer,
        };
    } else {
        return {
            header => '',
            body   => [$letter->{content}],
            footer => '',
        };
    }
}

=head2 Instance Methods

=head3 $message->update()

This saves the $message object back to the database.  It needs to have
already been created via C<enqueue> for this to work.

=cut

# $object->update -- save object to database
sub update {
    my ($self) = @_;
    my $dbh = C4::Context->dbh;
    $dbh->do(
        qq{
            UPDATE message_queue
            SET
                borrowernumber         = ?,
                subject                = ?,
                content                = ?,
                metadata               = ?,
                letter_code            = ?,
                message_transport_type = ?,
                status                 = ?,
                time_queued            = ?,
                to_address             = ?,
                from_address           = ?,
                content_type           = ?
            WHERE message_id = ?
        },
        {},
        $self->borrowernumber,
        $self->subject,
        $self->content,
        $self->{metadata}, # we want the raw YAML here
        $self->letter_code,
        $self->message_transport_type,
        $self->status,
        $self->time_queued,
        $self->to_address,
        $self->from_address,
        $self->content_type,
        $self->message_id
    );
}

=head3 $message->metadata(\%new_metadata)

This method automatically serializes and deserializes the metadata
attribute.  (It is stored in YAML format.)

=cut

# $object->metadata -- this is a YAML serialized column that contains a
# structured representation of $object->content
sub metadata {
    my ($self, $data) = @_;
    if ($data) {
        $data->{header} ||= '';
        $data->{body}   ||= [];
        $data->{footer} ||= '';
        $self->{metadata} = Encode::decode_utf8(Dump($data));
        $self->content($self->render_metadata);
        return $data;
    } else {
        return YAML::XS::Load(Encode::encode_utf8($self->{metadata}));
    }
}

# turn $object->metadata into a string suitable for $object->content
sub render_metadata {
    my ($self, $format) = @_;
    $format ||= sub { $_[0] || "" };
    my $metadata = $self->metadata;
    my $body     = $metadata->{body};
    my $text     = join('', map { $format->($_) } @$body);
    return $metadata->{header} . $text . $metadata->{footer};
}

=head3 $message->append(\%letter)

If passed a hashref, this method will assume that the hashref is in the form
that C<C4::Letters::getletter()> returns.  It will append the body of the
letter to the message.

=head3 $message->append($string)

If passed a string, it'll append the string to the message.

=cut

# $object->append($letter_or_item) -- add a new item to a message's content
sub append {
    my ($self, $letter_or_item, $format) = @_;
    my ( $item, $header, $footer );
    if (ref($letter_or_item)) {
        my $letter   = $letter_or_item;
        my $metadata = _metadata($letter);
        $header = $metadata->{header};
        $footer = $metadata->{footer};
        $item = $metadata->{body}->[0];
    } else {
        $item = $letter_or_item;
    }
    if (not $self->metadata) {
        carp "Can't append to messages that don't have metadata.";
        return;
    }
    my $metadata = $self->metadata;
    push @{$metadata->{body}}, $item;
    $metadata->{header} = $header;
    $metadata->{footer} = $footer;
    $self->metadata($metadata);
    my $new_content = $self->render_metadata($format);
    return $self->content($new_content);
}

=head2 Attributes Accessors

=head3 $message->message_id

=cut

=head3 $message->borrowernumber

=cut

=head3 $message->subject

=cut

=head3 $message->content

=cut

=head3 $message->metadata

=cut

=head3 $message->letter_code

=cut

=head3 $message->message_transport_type

=cut

=head3 $message->status

=cut

=head3 $message->time_queued

=cut

=head3 $message->to_address

=cut

=head3 $message->from_address

=cut

=head3 $message->content_type

=cut

# $object->$method -- treat keys as methods
sub AUTOLOAD {
    my ($self, @args) = @_;
    my $attr = $AUTOLOAD;
    $attr =~ s/.*://;
    if (ref($self->{$attr}) eq 'CODE') {
        $self->{$attr}->($self, @args);
    } else {
        if (@args) {
            $self->{$attr} = $args[0];
        } else {
            $self->{$attr};
        }
    }
}

sub DESTROY { }

1;

=head1 SEE ALSO

L<C4::Circulation>, L<C4::Letters>, L<C4::Members::Messaging>

=head1 AUTHOR

John Beppu <john.beppu@liblime.com>

=cut
