#!/usr/bin/perl

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

use Test::More tests => 2;
use Test::Exception;

use t::lib::Mocks;

use_ok('Koha::Email');

subtest 'create() tests' => sub {

    plan tests => 23;

    t::lib::Mocks::mock_preference( 'SendAllEmailsTo', undef );

    my $html_body = '<h1>Title</h1><p>Message</p>';
    my $text_body = "#Title: Message";

    my $email = Koha::Email->create(
        {
            from        => 'from@example.com',
            to          => 'to@example.com',
            cc          => 'cc@example.com',
            bcc         => 'bcc@example.com',
            reply_to    => 'reply_to@example.com',
            sender      => 'sender@example.com',
            subject     => 'Some subject',
            html_body   => $html_body,
            body_params => { charset => 'iso-8859-1' },
        }
    );

    is( $email->email->header('From'), 'from@example.com', 'Value set correctly' );
    is( $email->email->header('To'), 'to@example.com', 'Value set correctly' );
    is( $email->email->header('Cc'), 'cc@example.com', 'Value set correctly' );
    is( $email->email->header('Bcc'), 'bcc@example.com', 'Value set correctly' );
    is( $email->email->header('ReplyTo'), 'reply_to@example.com', 'Value set correctly' );
    is( $email->email->header('Sender'), 'sender@example.com', 'Value set correctly' );
    is( $email->email->header('Subject'), 'Some subject', 'Value set correctly' );
    is( $email->email->header('X-Mailer'), 'Koha', 'Value set correctly' );
    is( $email->email->body, $html_body, "Body set correctly" );
    like( $email->email->content_type, qr|text/html|, "Content type set correctly");
    like( $email->email->content_type, qr|charset="?iso-8859-1"?|, "Charset set correctly");
    like( $email->email->header('Message-ID'), qr/\<.*@.*\>/, 'Value set correctly' );

    t::lib::Mocks::mock_preference( 'SendAllEmailsTo', 'catchall@example.com' );
    t::lib::Mocks::mock_preference( 'ReplytoDefault', 'replytodefault@example.com' );
    t::lib::Mocks::mock_preference( 'ReturnpathDefault', 'returnpathdefault@example.com' );
    t::lib::Mocks::mock_preference( 'KohaAdminEmailAddress', 'kohaadminemailaddress@example.com' );

    $email = Koha::Email->create(
        {
            to        => 'to@example.com',
            cc        => 'cc@example.com',
            bcc       => 'bcc@example.com',
            text_body => $text_body,
        }
    );

    is( $email->email->header('From'), 'kohaadminemailaddress@example.com', 'KohaAdminEmailAddress is picked when no from passed' );
    is( $email->email->header('To'), 'catchall@example.com', 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('Cc'), undef, 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('Bcc'), undef, 'SendAllEmailsTo overloads any address' );
    is( $email->email->header('ReplyTo'), 'replytodefault@example.com', 'ReplytoDefault picked when replyto not passed' );
    is( $email->email->header('Sender'), 'returnpathdefault@example.com', 'ReturnpathDefault picked when sender not passed' );
    is( $email->email->header('Subject'), '', 'No subject passed, empty string' );
    is( $email->email->body, $text_body, "Body set correctly" );
    like( $email->email->content_type, qr|text/plain|, "Content type set correctly");
    like( $email->email->content_type, qr|charset="?utf-8"?|, "Charset set correctly");

    subtest 'exception cases' => sub {

        plan tests => 16;

        throws_ok
            { Koha::Email->create({ from => 'not_an_email' }); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'from' parameter: not_an_email}, 'Exception message correct' );

        t::lib::Mocks::mock_preference( 'KohaAdminEmailAddress', 'not_an_email' );

        throws_ok
            { Koha::Email->create({  }); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'from' parameter: not_an_email}, 'Exception message correct' );

        t::lib::Mocks::mock_preference( 'KohaAdminEmailAddress', 'tomasito@mail.com' );
        t::lib::Mocks::mock_preference( 'SendAllEmailsTo', undef );

        throws_ok
            { Koha::Email->create({ to => 'not_an_email' }); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'to' parameter: not_an_email}, 'Exception message correct' );

        t::lib::Mocks::mock_preference( 'SendAllEmailsTo', 'not_an_email' );

        throws_ok
            { Koha::Email->create({  }); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'to' parameter: not_an_email}, 'Exception message correct' );

        t::lib::Mocks::mock_preference( 'SendAllEmailsTo', undef );

        throws_ok
            { Koha::Email->create(
                {
                    to       => 'tomasito@mail.com',
                    reply_to => 'not_an_email'
                }
              ); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'reply_to' parameter: not_an_email}, 'Exception message correct' );

        throws_ok
            { Koha::Email->create(
                {
                    to     => 'tomasito@mail.com',
                    sender => 'not_an_email'
                }
              ); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'sender' parameter: not_an_email}, 'Exception message correct' );

        throws_ok
            { Koha::Email->create(
                {
                    to => 'tomasito@mail.com',
                    cc => 'not_an_email'
                }
              ); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'cc' parameter: not_an_email}, 'Exception message correct' );

        throws_ok
            { Koha::Email->create(
                {
                    to  => 'tomasito@mail.com',
                    bcc => 'not_an_email'
                }
              ); }
            'Koha::Exceptions::BadParameter',
            'Exception thrown correctly';

        is( "$@", q{Invalid 'bcc' parameter: not_an_email}, 'Exception message correct' );
    };
};
