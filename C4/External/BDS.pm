package C4::External::BDS;

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request::Common;

use strict;
use warnings;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    require Exporter;
    $VERSION = 3.07.00.049;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        &get_bds_index
        &get_bds_summary
        &get_bds_toc
        &get_bds_editions
        &get_bds_excerpt
        &get_bds_reviews
        &get_bds_anotes
    );
}

=head1 NAME

C4::External::BDS - Functions for retrieving BDS content in Koha

=head1 FUNCTIONS

This module provides facilities for retrieving BDS content in Koha

=head2 get_bds_summary

  my $bds_summary= &get_bds_summary( $isbn );

Get Summary data from BDS

=cut

sub get_bds_index {
    my ( $isbn, $upc, $oclc ) = @_;

    return unless ( $isbn || $upc || $oclc );

    my $response = _fetch_bds_content('INDEX.XML', $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;
    my $xmlsimple = XML::Simple->new();
    $response = $xmlsimple->XMLin(
        $content,
    ) unless !$content;

    my $bds_elements;
    for my $available_type ('SUMMARY','TOC','FICTION','AWARDS1','SERIES1','SPSUMMARY','SPREVIEW', 'AVPROFILE', 'AVSUMMARY','DBCHAPTER','LJREVIEW','PWREVIEW','SLJREVIEW','CHREVIEW','BLREVIEW','HBREVIEW','KIREVIEW','CRITICASREVIEW','ANOTES') {
        if (exists $response->{$available_type} && $response->{$available_type} =~ /$available_type/) {
            $bds_elements->{$available_type} = $available_type;
        }
    }

    return $bds_elements if $bds_elements;
}

sub get_bds_summary {
    my ( $isbn, $upc, $oclc, $bds_elements ) = @_;

    my $summary_type = exists($bds_elements->{'AVSUMMARY'}) ? 'AVSUMMARY.XML' : 'SUMMARY.XML';
    my $response = _fetch_bds_content($summary_type, $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;

    my $summary;
    eval {
        my $doc = $parser->parse_string($content);
        $summary = $doc->findvalue('//Fld520');
    };
    if ($@) {
        warn "Error parsing BDS $summary_type";
    }
    return $summary if $summary;
}

sub get_bds_toc {
    my ( $isbn,$upc,$oclc ) = @_;

    my $response = _fetch_bds_content('TOC.XML', $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;
    my $xmlsimple = XML::Simple->new();
    $response = $xmlsimple->XMLin(
        $content,
        forcearray => [ qw(Fld970) ],
    ) unless !$content;
    # manipulate response USMARC VarFlds VarDFlds Notes Fld520 a
    my $toc;
    $toc = \@{$response->{VarFlds}->{VarDFlds}->{SSIFlds}->{Fld970}} if $response;
    return $toc if $toc;
}

sub get_bds_excerpt {
    my ( $isbn,$upc,$oclc ) = @_;

    my $response = _fetch_bds_content('DBCHAPTER.XML', $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;
    my $xmlsimple = XML::Simple->new();
    $response = $xmlsimple->XMLin(
        $content,
        forcearray => [ qw(Fld520) ],
    ) unless !$content;
    # manipulate response USMARC VarFlds VarDFlds Notes Fld520 a
    my $excerpt;
    $excerpt = \@{$response->{VarFlds}->{VarDFlds}->{Notes}->{Fld520}} if $response;
    return XMLout($excerpt, NoEscape => 1) if $excerpt;
}

sub get_bds_reviews {
    my ( $isbn,$upc,$oclc,$bds_elements ) = @_;

    my @reviews;
    my $review_sources = [
    {title => 'Library Journal Review', file => 'LJREVIEW.XML', element => 'LJREVIEW'},
    {title => 'Publishers Weekly Review', file => 'PWREVIEW.XML', element => 'PWREVIEW'},
    {title => 'School Library Journal Review', file => 'SLJREVIEW.XML', element => 'SLJREVIEW'},
    {title => 'CHOICE Review', file => 'CHREVIEW.XML', element => 'CHREVIEW'},
    {title => 'Booklist Review', file => 'BLREVIEW.XML', element => 'BLREVIEW'},
    {title => 'Horn Book Review', file => 'HBREVIEW.XML', element => 'HBREVIEW'},
    {title => 'Kirkus Book Review', file => 'KIREVIEW.XML', element => 'KIREVIEW'},
    {title => 'Criticas Review', file => 'CRITICASREVIEW.XML', element => 'CRITICASREVIEW'},
    {title => 'Spanish Review', file => 'SPREVIEW.XML', element => 'SPREVIEW'},
    ];

    for my $source (@$review_sources) {
        if ($bds_elements->{$source->{element}} and $source->{element} =~ $bds_elements->{$source->{element}}) {

        } else {
            #warn "Skipping $source->{element} doesn't match $bds_elements->{$source->{element}} \n";
            next;
        }
        my $response = _fetch_bds_content($source->{file}, $isbn, $upc, $oclc);
        unless ($response->content_type =~ /xml/) {
            next;
        }

        my $content = $response->content;

        eval {
            my $doc = $parser->parse_string($content);

            # note that using findvalue strips any HTML elements embedded
            # in that review.  That helps us handle slight differences
            # in the output provided by BDS 'old' and 'new' versions
            # of their service and cleans any questionable HTML that
            # may be present in the reviews, but does mean that any
            # <B> and <I> tags used to format the review are also gone.
            my $result = $doc->findvalue('//Fld520');
            push @reviews, {title => $source->{title}, reviews => [ { content => $result } ]} if $result;
        };
        if ($@) {
            warn "Error parsing BDS $source->{title} review";
        }
    }
    return \@reviews;
}

sub get_bds_editions {
    my ( $isbn,$upc,$oclc ) = @_;

    my $response = _fetch_bds_content('FICTION.XML', $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;

    my $xmlsimple = XML::Simple->new();
    $response = $xmlsimple->XMLin(
        $content,
        forcearray => [ qw(Fld020) ],
    ) unless !$content;
    # manipulate response USMARC VarFlds VarDFlds Notes Fld520 a
    my $similar_items;
    $similar_items = \@{$response->{VarFlds}->{VarDFlds}->{NumbCode}->{Fld020}} if $response;
    return $similar_items if $similar_items;
}

sub get_bds_anotes {
    my ( $isbn,$upc,$oclc) = @_;

    my $response = _fetch_bds_content('ANOTES.XML', $isbn, $upc, $oclc);
    unless ($response->content_type =~ /xml/) {
        return;
    }

    my $content = $response->content;

    my $xmlsimple = XML::Simple->new();
    $response = $xmlsimple->XMLin(
        $content,
        forcearray => [ qw(Fld980) ],
        ForceContent => 1,
    ) unless !$content;
    my @anotes;
    for my $fld980 (@{$response->{VarFlds}->{VarDFlds}->{SSIFlds}->{Fld980}}) {
        # this is absurd, but sometimes this data serializes differently
        if(ref($fld980->{a}->{content}) eq 'ARRAY') {
            for my $content (@{$fld980->{a}->{content}}) {
                push @anotes, {content => $content};

            }
        }
        else {
            push @anotes, {content => $fld980->{a}->{content}};
        }
    }
    return \@anotes;
}

sub _fetch_bds_content {
    my ( $element, $isbn, $upc, $oclc ) = @_;

    $isbn = '' unless defined $isbn;
    $upc  = '' unless defined $upc;
    $oclc = '' unless defined $oclc;

    my $bds_client_code = C4::Context->preference('BDSClientCode');

    my $url = "http://www.bds.com/index.aspx?isbn=$isbn/$element&client=$bds_client_code&type=xw10&upc=$upc&oclc=$oclc";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    my $response = $ua->get($url);

    warn "could not retrieve $url" unless $response->content;
    return $response;

}
1;
__END__

=head1 NOTES

=cut

=head1 AUTHOR

Martin Renvoize <martin.renvoize@ptfs-europe.com>

=cut
