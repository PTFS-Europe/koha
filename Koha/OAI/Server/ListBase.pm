package Koha::OAI::Server::ListBase;

# Copyright The National Library of Finland, University of Helsinki 2016-2018
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

=head1 NAME

Koha::OAI::Server::ListBase - OAI ListIdentifiers/ListRecords shared functionality

=head1 DESCRIPTION

Koha::OAI::Server::ListBase contains OAI-PMH functions shared by ListIdentifiers and ListRecords.

=cut

use Modern::Perl;
use C4::Biblio;
use HTTP::OAI;
use Koha::OAI::Server::ResumptionToken;
use Koha::OAI::Server::Record;
use Koha::OAI::Server::DeletedRecord;
use C4::OAI::Sets;
use MARC::File::XML;

sub GetRecords {
    my ($class, $self, $repository, $metadata, %args) = @_;

    my $token = new Koha::OAI::Server::ResumptionToken( %args );
    my $dbh = C4::Context->dbh;
    my $set;
    if ( defined $token->{'set'} ) {
        $set = GetOAISetBySpec($token->{'set'});
    }
    my $offset = $token->{offset};
    my $max = $repository->{koha_max_count};
    my $count = 0;
    my $format = $args{metadataPrefix} || $token->{metadata_prefix};
    my $include_items = $repository->items_included( $format );

    my $sql = "
        SELECT biblionumber, deleted_on
        FROM biblio_metadata
        WHERE (timestamp >= ? AND timestamp <= ?)
    ";
    my @bind_params = ($token->{'from_arg'}, $token->{'until_arg'});

    if ($include_items) {
        $sql .= "
            OR biblionumber IN (SELECT biblionumber from items WHERE timestamp >= ? AND timestamp <= ?)
        ";
        push @bind_params, ($token->{'from_arg'}, $token->{'until_arg'});
    }

    $sql .= "
        ORDER BY biblionumber
    ";

    # Use a subquery for sets since it allows us to use an index in
    # biblioitems table and is quite a bit faster than a join.
    if (defined $set) {
        $sql = "
            SELECT bi.* FROM ($sql) bi
                WHERE bi.biblionumber in (SELECT osb.biblionumber FROM oai_sets_biblios osb WHERE osb.set_id = ?)
        ";
        push @bind_params, $set->{'id'};
    }

    $sql .= "
        LIMIT " . ($max + 1) . "
        OFFSET $offset";

    my $sth = $dbh->prepare( $sql ) || die( 'Could not prepare statement: ' . $dbh->errstr );

    $sql = "
        SELECT MAX(timestamp)
        FROM (
            SELECT timestamp FROM biblio_metadata WHERE biblionumber = ?
            UNION
            SELECT timestamp FROM items WHERE biblionumber = ?
        ) bi
    ";
    my $record_sth = $dbh->prepare( $sql ) || die( 'Could not prepare statement: ' . $dbh->errstr );

    $sth->execute( @bind_params ) || die( 'Could not execute statement: ' . $sth->errstr );
    while ( my ($biblionumber, $deleted_on) = $sth->fetchrow ) {
        $count++;
        if ( $count > $max ) {
            $self->resumptionToken(
                new Koha::OAI::Server::ResumptionToken(
                    metadataPrefix  => $token->{metadata_prefix},
                    from            => $token->{from},
                    until           => $token->{until},
                    offset          => $token->{offset} + $max,
                    set             => $token->{set},
                )
            );
            last;
        }
        $record_sth->execute( ( $biblionumber, $biblionumber ) ) || die( 'Could not execute statement: ' . $sth->errstr );

        my ($timestamp) = $record_sth->fetchrow;

        my $oai_sets = GetOAISetsBiblio($biblionumber);
        my @setSpecs;
        foreach ( @$oai_sets ) {
            push @setSpecs, $_->{spec};
        }
        if ( $metadata ) {
            my $marcxml = !$deleted_on ? $repository->get_biblio_marcxml($biblionumber, $format) : undef;
            if ( $marcxml ) {
                $self->record( Koha::OAI::Server::Record->new(
                    $repository, $marcxml, $timestamp, \@setSpecs,
                    identifier      => $repository->{ koha_identifier } . ':' . $biblionumber,
                    metadataPrefix  => $token->{metadata_prefix}
                ) );
            } else {
                $self->record( Koha::OAI::Server::DeletedRecord->new(
                    $timestamp, \@setSpecs, identifier => $repository->{ koha_identifier } . ':' . $biblionumber
                ) );
            }
        } else {
            $timestamp =~ s/ /T/;
            $timestamp .= 'Z';
            $self->identifier( new HTTP::OAI::Header(
                identifier => $repository->{ koha_identifier} . ':' . $biblionumber,
                datestamp  => $timestamp,
                status     => $deleted_on ? 'deleted' : undef
            ) );
        }
    }
    # Store offset
    $offset += $count;
    return $count;
}

1;
