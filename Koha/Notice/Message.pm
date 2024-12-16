package Koha::Notice::Message;

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

use Koha::Database;
use Koha::Patron::Debarments qw( AddDebarment );

use base qw(Koha::Object);

=head1 NAME

Koha::Notice::Message - Koha notice message Object class, related to the message_queue table

=head1 API

=head2 Class Methods

=cut

=head3 is_html

  my $bool = $message->is_html;

Returns a boolean denoting whether the message was generated using a preformatted html template.

=cut

sub is_html {
    my ($self) = @_;
    my $content_type = $self->content_type // '';
    return $content_type =~ m/html/io;
}

=head3 html_content

  my $wrapped_content = $message->html_content;

This method returns the message content appropriately wrapped
with HTML headers and CSS includes for HTML formatted notices.

=cut

sub html_content {
    my ($self) = @_;

    my $title       = $self->subject;
    my $content     = $self->content;
    my $stylesheets = $self->stylesheets;

    my $wrapped;
    if ( $self->is_html ) {

        my $css = C4::Context->preference("NoticeCSS") || '';
        $css = qq{<link rel="stylesheet" type="text/css" href="$css">} if $css;

        $wrapped = <<EOS;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html lang="en" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    $stylesheets
  </head>
  <body>
  $content
  </body>
</html>
EOS
    } else {
        $wrapped = "<div style=\"white-space: pre-wrap;\">";
        $wrapped .= $content;
        $wrapped .= "</div>";
    }
    return $wrapped;
}

=head3 restrict_patron_when_notice_fails

    $failed_notice->restrict_patron_when_notice_fails;

Places a restriction (debarment) on patrons with failed SMS and email notices.

=cut

sub restrict_patron_when_notice_fails {
    my ($self) = @_;

    # Set the appropriate restriction (debarment) comment depending if the failed
    # message is a SMS or email notice. If the failed notice is neither then
    # return without placing a restriction
    my $comment;
    if ( $self->message_transport_type eq 'email' ) {
        $comment = 'Email address invalid';
    } elsif ( $self->message_transport_type eq 'sms' ) {
        $comment = 'SMS number invalid';
    } else {
        return;
    }

    AddDebarment(
        {
            borrowernumber => $self->borrowernumber,
            type           => 'NOTICE_FAILURE_SUSPENSION',
            comment        => $comment,
            expiration     => undef,
        }
    );

    return $self;
}

=head3 stylesheets

  my $stylesheets = $message->stylesheets;

Returns a string of all the stylesheet links for the message

=cut

sub stylesheets {
    my ($self) = @_;

    my $all_stylesheets = C4::Context->preference("AllNoticeStylesheet") || '';
    $all_stylesheets .= qq{<link rel="stylesheet" type="text/css" href="$all_stylesheets">\n} if $all_stylesheets;
    my $all_style_pref = C4::Context->preference("AllNoticeCSS");
    $all_stylesheets .= qq{<style type="text/css">$all_style_pref</style>} if $all_style_pref;
    if ( $self->message_transport_type eq 'email' ) {
        my $email_stylesheet = C4::Context->preference("EmailNoticeStylesheet") || '';
        $all_stylesheets .= qq{<link rel="stylesheet" type="text/css" href="$email_stylesheet">\n} if $email_stylesheet;
        my $email_style_pref = C4::Context->preference("EmailNoticeCSS");
        $all_stylesheets .= qq{<style type="text/css">$email_style_pref</style>} if $email_style_pref;
    }
    if ( $self->message_transport_type eq 'print' ) {
        my $print_stylesheet = C4::Context->preference("PrintNoticeStylesheet") || '';
        $all_stylesheets .= qq{<link rel="stylesheet" type="text/css" href="$print_stylesheet">\n} if $print_stylesheet;
        my $print_style_pref = C4::Context->preference("PrintNoticeCSS");
        $all_stylesheets .= qq{<style type="text/css">$print_style_pref</style>\n} if $print_style_pref;
    }

    return $all_stylesheets;
}

=head3 scoped_style

  my $scoped_style = $message->scoped_style;

Returns a string of all the scoped styles for the message

=cut

sub scoped_style {
    my ($self)       = @_;
    my $type         = $self->message_transport_type;
    my $scoped_class = ".type_$type";
    my $css_content;

    if ( $self->message_transport_type eq 'email' ) {
        $css_content = C4::Context->preference("EmailNoticeCSS");
    } elsif ( $self->message_transport_type eq 'print' ) {
        $css_content = C4::Context->preference("PrintNoticeCSS");
    }

    # Modify the CSS content, handling @media, @supports, @document
    $css_content =~ s!
        (@(media|supports|-moz-document)[^\{]+\{)  # Match the at-rule start
        (                                         # Capture group for block content
          (?:                                     # Non-capturing group
            [^{]+\{[^}]*\}                        # Match CSS rules within the at-rule block
          )*
        )
        \}
    !
        my $header = $1;
        my $inner_rules = $2;                     # Capture the rules within the at-rule block

        # Apply the scoped class to the inner rules
        $inner_rules =~ s/([^{]+)\{/ $scoped_class $1\{/g;

        # Return the modified block
        "$header$inner_rules"

    !egx;

    $css_content =~ s/([^{]+)\{/$scoped_class $1\{/g
        unless $css_content =~ /\@(media|supports|-moz-document)/;

    return $css_content;
}

=head3 patron

    my $patron = $checkout->patron

Return the patron by whom the checkout was done

=cut

sub patron {
    my ($self) = @_;
    my $patron_rs = $self->_result->borrowernumber;
    return unless $patron_rs;
    return Koha::Patron->_new_from_dbic($patron_rs);
}

=head3 type

=cut

sub _type {
    return 'MessageQueue';
}

1;
