#!/usr/bin/perl

# Copyright 2009 SARL Biblibre
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

use CGI qw ( -utf8 );
use Encode qw( encode );
use Carp;

use Mail::Sendmail;
use MIME::QuotedPrint;
use MIME::Base64;
use C4::Auth;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::Members;
use Koha::Email;
use Koha::Patrons;
use Koha::Virtualshelves;

my $query = new CGI;

# if virtualshelves is disabled, leave immediately
if ( ! C4::Context->preference('virtualshelves') ) {
    print $query->redirect("/cgi-bin/koha/errors/404.pl");
    exit;
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user (
    {
        template_name   => "opac-sendshelfform.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
    }
);

my $shelfid = $query->param('shelfid');
my $email   = $query->param('email');

my $dbh          = C4::Context->dbh;

my $shelf = Koha::Virtualshelves->find( $shelfid );
if ( $shelf and $shelf->can_be_viewed( $borrowernumber ) ) {

if ( $email ) {
    my $message = Koha::Email->new();
    my $comment    = $query->param('comment');

    my %mail = $message->create_message_headers(
        {
            to => $email,
        }
    );

    my ( $template2, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "opac-sendshelf.tt",
            query           => $query,
            type            => "opac",
            authnotrequired => 1,
        }
    );

    my $patron = Koha::Patrons->find( $borrowernumber );
    my $borcat = $patron ? $patron->categorycode : q{};

    my $shelf = Koha::Virtualshelves->find( $shelfid );
    my $contents = $shelf->get_contents;
    my $marcflavour         = C4::Context->preference('marcflavour');
    my $iso2709;
    my @results;

    while ( my $content = $contents->next ) {
        my $biblionumber = $content->biblionumber;
        my $record           = GetMarcBiblio({
            biblionumber => $biblionumber,
            embed_items  => 1,
            opac         => 1,
            borcat       => $borcat });
        next unless $record;
        my $fw               = GetFrameworkCode($biblionumber);
        my $dat              = GetBiblioData($biblionumber);

        my $marcauthorsarray = GetMarcAuthors( $record, $marcflavour );
        my $marcsubjctsarray = GetMarcSubjects( $record, $marcflavour );
        my $subtitle         = GetRecordValue('subtitle', $record, $fw);

        my @items = GetItemsInfo( $biblionumber );

        $dat->{ISBN}           = GetMarcISBN($record, $marcflavour);
        $dat->{MARCSUBJCTS}    = $marcsubjctsarray;
        $dat->{MARCAUTHORS}    = $marcauthorsarray;
        $dat->{'biblionumber'} = $biblionumber;
        $dat->{ITEM_RESULTS}   = \@items;
        $dat->{subtitle}       = $subtitle;
        $dat->{HASAUTHORS}     = $dat->{'author'} || @$marcauthorsarray;

        $iso2709 .= $record->as_usmarc();

        push( @results, $dat );
    }

    $template2->param(
        BIBLIO_RESULTS => \@results,
        comment        => $comment,
        shelfname      => $shelf->shelfname,
        firstname      => $patron->firstname,
        surname        => $patron->surname,
    );

    # Getting template result
    my $template_res = $template2->output();
    my $body;

    # Analysing information and getting mail properties
    if ( $template_res =~ /<SUBJECT>(.*)<END_SUBJECT>/s ) {
        $mail{subject} = $1;
        $mail{subject} =~ s|\n?(.*)\n?|$1|;
    }
    else { $mail{'subject'} = "no subject"; }
    $mail{subject} = encode('MIME-Header', $mail{subject});

    my $email_header = "";
    if ( $template_res =~ /<HEADER>(.*)<END_HEADER>/s ) {
        $email_header = $1;
        $email_header =~ s|\n?(.*)\n?|$1|;
        $email_header = encode_qp(Encode::encode("UTF-8", $email_header));
    }

    my $email_file = "list.txt";
    if ( $template_res =~ /<FILENAME>(.*)<END_FILENAME>/s ) {
        $email_file = $1;
        $email_file =~ s|\n?(.*)\n?|$1|;
    }

    if ( $template_res =~ /<MESSAGE>(.*)<END_MESSAGE>/s ) {
        $body = $1;
        $body =~ s|\n?(.*)\n?|$1|;
        $body = encode_qp(Encode::encode("UTF-8", $body));
    }

    my $boundary = "====" . time() . "====";

    # We set and put the multipart content
    $mail{'content-type'} = "multipart/mixed; boundary=\"$boundary\"";

    my $isofile = encode_base64(encode("UTF-8", $iso2709));
    $boundary = '--' . $boundary;

    $mail{body} = <<END_OF_BODY;
$boundary
MIME-Version: 1.0
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: quoted-printable

$email_header
$body
$boundary
Content-Type: application/octet-stream; name="list.iso2709"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="list.iso2709"

$isofile
$boundary--
END_OF_BODY

    # Sending mail
    if ( sendmail %mail ) {
        # do something if it works....
        $template->param( SENT      => "1" );
    }
    else {
        # do something if it doesn't work....
        carp "Error sending mail: $Mail::Sendmail::error \n";
        $template->param( error => 1 );
    }

    $template->param(
        shelfid => $shelfid,
        email => $email,
    );
    output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };


}else{
    $template->param( shelfid => $shelfid,
                      url     => "/cgi-bin/koha/opac-sendshelf.pl",
                    );
    output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
}

} else {
    $template->param( invalidlist => 1,
                      url     => "/cgi-bin/koha/opac-sendshelf.pl",
    );
    output_html_with_http_headers $query, $cookie, $template->output, undef, { force_no_caching => 1 };
}
