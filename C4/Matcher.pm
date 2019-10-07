package C4::Matcher;

# Copyright (C) 2007 LibLime, 2012 C & P Bibliography Services
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

use MARC::Record;

use Koha::SearchEngine;
use Koha::SearchEngine::Search;
use Koha::SearchEngine::QueryBuilder;
use Koha::Util::Normalize qw/legacy_default remove_spaces upper_case lower_case/;

=head1 NAME

C4::Matcher - find MARC records matching another one

=head1 SYNOPSIS

  my @matchers = C4::Matcher::GetMatcherList();

  my $matcher = C4::Matcher->new($record_type);
  $matcher->threshold($threshold);
  $matcher->code($code);
  $matcher->description($description);

  $matcher->add_simple_matchpoint('isbn', 1000, '020', 'a', -1, 0, '');
  $matcher->add_simple_matchpoint('Date', 1000, '008', '', 7, 4, '');
  $matcher->add_matchpoint('isbn', 1000, [ { tag => '020', subfields => 'a', norms => [] } ]);

  $matcher->add_simple_required_check('245', 'a', -1, 0, '', '245', 'a', -1, 0, '');
  $matcher->add_required_check([ { tag => '245', subfields => 'a', norms => [] } ],
                               [ { tag => '245', subfields => 'a', norms => [] } ]);

  my @matches = $matcher->get_matches($marc_record, $max_matches);

  foreach $match (@matches) {

      # matches already sorted in order of
      # decreasing score
      print "record ID: $match->{'record_id'};
      print "score:     $match->{'score'};

  }

  my $matcher_description = $matcher->dump();

=head1 FUNCTIONS

=cut

=head2 GetMatcherList

  my @matchers = C4::Matcher::GetMatcherList();

Returns an array of hashrefs list all matchers
present in the database.  Each hashref includes:

 * matcher_id
 * code
 * description

=cut

sub GetMatcherList {
    my $dbh = C4::Context->dbh;
    
    my $sth = $dbh->prepare_cached("SELECT matcher_id, code, description FROM marc_matchers ORDER BY matcher_id");
    $sth->execute();
    my @results = ();
    while (my $row = $sth->fetchrow_hashref) {
        push @results, $row;
    } 
    return @results;
}

=head2 GetMatcherId

  my $matcher_id = C4::Matcher::GetMatcherId($code);

Returns the matcher_id of a code.

=cut

sub GetMatcherId {
    my ($code) = @_;
    my $dbh = C4::Context->dbh;

    my $matcher_id = $dbh->selectrow_array("SELECT matcher_id FROM marc_matchers WHERE code = ?", undef, $code);
    return $matcher_id;
}

=head1 METHODS

=head2 new

  my $matcher = C4::Matcher->new($record_type, $threshold);

Creates a new Matcher.  C<$record_type> indicates which search
database to use, e.g., 'biblio' or 'authority' and defaults to
'biblio', while C<$threshold> is the minimum score required for a match
and defaults to 1000.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{'id'} = undef;

    if ($#_ > -1) {
        $self->{'record_type'} = shift;
    } else {
        $self->{'record_type'} = 'biblio';
    }

    if ($#_ > -1) {
        $self->{'threshold'} = shift;
    } else {
        $self->{'threshold'} = 1000;
    }

    $self->{'code'} = '';
    $self->{'description'} = '';

    $self->{'matchpoints'} = [];
    $self->{'required_checks'} = [];

    bless $self, $class;
    return $self;
}

=head2 fetch

  my $matcher = C4::Matcher->fetch($id);

Creates a matcher object from the version stored
in the database.  If a matcher with the given
id does not exist, returns undef.

=cut

sub fetch {
    my $class = shift;
    my $id = shift;
    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare_cached("SELECT * FROM marc_matchers WHERE matcher_id = ?");
    $sth->execute($id);
    my $row = $sth->fetchrow_hashref;
    $sth->finish();
    return undef unless defined $row;

    my $self = {};
    $self->{'id'} = $row->{'matcher_id'};
    $self->{'record_type'} = $row->{'record_type'};
    $self->{'code'} = $row->{'code'};
    $self->{'description'} = $row->{'description'};
    $self->{'threshold'} = int($row->{'threshold'});
    bless $self, $class;

    # matchpoints
    $self->{'matchpoints'} = [];
    $sth = $dbh->prepare_cached("SELECT * FROM matcher_matchpoints WHERE matcher_id = ? ORDER BY matchpoint_id");
    $sth->execute($self->{'id'});
    while (my $row = $sth->fetchrow_hashref) {
        my $matchpoint = $self->_fetch_matchpoint($row->{'matchpoint_id'});
        push @{ $self->{'matchpoints'} }, $matchpoint;
    }

    # required checks
    $self->{'required_checks'} = [];
    $sth = $dbh->prepare_cached("SELECT * FROM matchchecks WHERE matcher_id = ? ORDER BY matchcheck_id");
    $sth->execute($self->{'id'});
    while (my $row = $sth->fetchrow_hashref) {
        my $source_matchpoint = $self->_fetch_matchpoint($row->{'source_matchpoint_id'});
        my $target_matchpoint = $self->_fetch_matchpoint($row->{'target_matchpoint_id'});
        my $matchcheck = {};
        $matchcheck->{'source_matchpoint'} = $source_matchpoint;
        $matchcheck->{'target_matchpoint'} = $target_matchpoint;
        push @{ $self->{'required_checks'} }, $matchcheck;
    }

    return $self;
}

sub _fetch_matchpoint {
    my $self = shift;
    my $matchpoint_id = shift;
    
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare_cached("SELECT * FROM matchpoints WHERE matchpoint_id = ?");
    $sth->execute($matchpoint_id);
    my $row = $sth->fetchrow_hashref;
    my $matchpoint = {};
    $matchpoint->{'index'} = $row->{'search_index'};
    $matchpoint->{'score'} = int($row->{'score'});
    $sth->finish();

    $matchpoint->{'components'} = [];
    $sth = $dbh->prepare_cached("SELECT * FROM matchpoint_components WHERE matchpoint_id = ? ORDER BY sequence");
    $sth->execute($matchpoint_id);
    while ($row = $sth->fetchrow_hashref) {
        my $component = {};
        $component->{'tag'} = $row->{'tag'};
        $component->{'subfields'} = { map { $_ => 1 } split(//,  $row->{'subfields'}) };
        $component->{'offset'} = int($row->{'offset'});
        $component->{'length'} = int($row->{'length'});
        $component->{'norms'} = [];
        my $sth2 = $dbh->prepare_cached("SELECT * 
                                         FROM matchpoint_component_norms 
                                         WHERE matchpoint_component_id = ? ORDER BY sequence");
        $sth2->execute($row->{'matchpoint_component_id'});
        while (my $row2 = $sth2->fetchrow_hashref) {
            push @{ $component->{'norms'} }, $row2->{'norm_routine'};
        }
        push @{ $matchpoint->{'components'} }, $component;
    }
    return $matchpoint;
}

=head2 store

  my $id = $matcher->store();

Stores matcher in database.  The return value is the ID 
of the marc_matchers row.  If the matcher was 
previously retrieved from the database via the fetch()
method, the DB representation of the matcher
is replaced.

=cut

sub store {
    my $self = shift;

    if (defined $self->{'id'}) {
        # update
        $self->_del_matcher_components();
        $self->_update_marc_matchers();
    } else {
        # create new
        $self->_new_marc_matchers();
    }
    $self->_store_matcher_components();
    return $self->{'id'};
}

sub _del_matcher_components {
    my $self = shift;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare_cached("DELETE FROM matchpoints WHERE matcher_id = ?");
    $sth->execute($self->{'id'});
    $sth = $dbh->prepare_cached("DELETE FROM matchchecks WHERE matcher_id = ?");
    $sth->execute($self->{'id'});
    # foreign key delete cascades take care of deleting relevant rows
    # from matcher_matchpoints, matchpoint_components, and
    # matchpoint_component_norms
}

sub _update_marc_matchers {
    my $self = shift;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare_cached("UPDATE marc_matchers 
                                    SET code = ?,
                                        description = ?,
                                        record_type = ?,
                                        threshold = ?
                                    WHERE matcher_id = ?");
    $sth->execute($self->{'code'}, $self->{'description'}, $self->{'record_type'}, $self->{'threshold'}, $self->{'id'});
}

sub _new_marc_matchers {
    my $self = shift;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare_cached("INSERT INTO marc_matchers
                                    (code, description, record_type, threshold)
                                    VALUES (?, ?, ?, ?)");
    $sth->execute($self->{'code'}, $self->{'description'}, $self->{'record_type'}, $self->{'threshold'});
    $self->{'id'} = $dbh->{'mysql_insertid'};
}

sub _store_matcher_components {
    my $self = shift;

    my $dbh = C4::Context->dbh();
    my $sth;
    my $matcher_id = $self->{'id'};
    foreach my $matchpoint (@{ $self->{'matchpoints'}}) {
        my $matchpoint_id = $self->_store_matchpoint($matchpoint);
        $sth = $dbh->prepare_cached("INSERT INTO matcher_matchpoints (matcher_id, matchpoint_id)
                                     VALUES (?, ?)");
        $sth->execute($matcher_id, $matchpoint_id);
    }
    foreach my $matchcheck (@{ $self->{'required_checks'} }) {
        my $source_matchpoint_id = $self->_store_matchpoint($matchcheck->{'source_matchpoint'});
        my $target_matchpoint_id = $self->_store_matchpoint($matchcheck->{'target_matchpoint'});
        $sth = $dbh->prepare_cached("INSERT INTO matchchecks
                                     (matcher_id, source_matchpoint_id, target_matchpoint_id)
                                     VALUES (?, ?, ?)");
        $sth->execute($matcher_id, $source_matchpoint_id,  $target_matchpoint_id);
    }

}

sub _store_matchpoint {
    my $self = shift;
    my $matchpoint = shift;

    my $dbh = C4::Context->dbh();
    my $sth;
    my $matcher_id = $self->{'id'};
    $sth = $dbh->prepare_cached("INSERT INTO matchpoints (matcher_id, search_index, score)
                                 VALUES (?, ?, ?)");
    $sth->execute($matcher_id, $matchpoint->{'index'}, $matchpoint->{'score'}||0);
    my $matchpoint_id = $dbh->{'mysql_insertid'};
    my $seqnum = 0;
    foreach my $component (@{ $matchpoint->{'components'} }) {
        $seqnum++;
        $sth = $dbh->prepare_cached("INSERT INTO matchpoint_components 
                                     (matchpoint_id, sequence, tag, subfields, offset, length)
                                     VALUES (?, ?, ?, ?, ?, ?)");
        $sth->bind_param(1, $matchpoint_id);
        $sth->bind_param(2, $seqnum);
        $sth->bind_param(3, $component->{'tag'});
        $sth->bind_param(4, join "", sort keys %{ $component->{'subfields'} });
        $sth->bind_param(5, $component->{'offset'}||0);
        $sth->bind_param(6, $component->{'length'});
        $sth->execute();
        my $matchpoint_component_id = $dbh->{'mysql_insertid'};
        my $normseq = 0;
        foreach my $norm (@{ $component->{'norms'} }) {
            $normseq++;
            $sth = $dbh->prepare_cached("INSERT INTO matchpoint_component_norms
                                         (matchpoint_component_id, sequence, norm_routine)
                                         VALUES (?, ?, ?)");
            $sth->execute($matchpoint_component_id, $normseq, $norm);
        }
    }
    return $matchpoint_id;
}


=head2 delete

  C4::Matcher->delete($id);

Deletes the matcher of the specified ID
from the database.

=cut

sub delete {
    my $class = shift;
    my $matcher_id = shift;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM marc_matchers WHERE matcher_id = ?");
    $sth->execute($matcher_id); # relying on cascading deletes to clean up everything
}

=head2 record_type

  $matcher->record_type('biblio');
  my $record_type = $matcher->record_type();

Accessor method.

=cut

sub record_type {
    my $self = shift;
    @_ ? $self->{'record_type'} = shift : $self->{'record_type'};
}

=head2 threshold

  $matcher->threshold(1000);
  my $threshold = $matcher->threshold();

Accessor method.

=cut

sub threshold {
    my $self = shift;
    @_ ? $self->{'threshold'} = shift : $self->{'threshold'};
}

=head2 _id

  $matcher->_id(123);
  my $id = $matcher->_id();

Accessor method.  Note that using this method
to set the DB ID of the matcher should not be
done outside of the editing CGI.

=cut

sub _id {
    my $self = shift;
    @_ ? $self->{'id'} = shift : $self->{'id'};
}

=head2 code

  $matcher->code('ISBN');
  my $code = $matcher->code();

Accessor method.

=cut

sub code {
    my $self = shift;
    @_ ? $self->{'code'} = shift : $self->{'code'};
}

=head2 description

  $matcher->description('match on ISBN');
  my $description = $matcher->description();

Accessor method.

=cut

sub description {
    my $self = shift;
    @_ ? $self->{'description'} = shift : $self->{'description'};
}

=head2 add_matchpoint

  $matcher->add_matchpoint($index, $score, $matchcomponents);

Adds a matchpoint that may include multiple components.  The $index
parameter identifies the index that will be searched, while $score
is the weight that will be added if a match is found.

$matchcomponents should be a reference to an array of matchpoint
compoents, each of which should be a hash containing the following 
keys:
    tag
    subfields
    offset
    length
    norms

The normalization_rules value should in turn be a reference to an
array, each element of which should be a reference to a 
normalization subroutine (under C4::Normalize) to be applied
to the source string.

=cut
    
sub add_matchpoint {
    my $self = shift;
    my ($index, $score, $matchcomponents) = @_;

    my $matchpoint = {};
    $matchpoint->{'index'} = $index;
    $matchpoint->{'score'} = $score;
    $matchpoint->{'components'} = [];
    foreach my $input_component (@{ $matchcomponents }) {
        push @{ $matchpoint->{'components'} }, _parse_match_component($input_component);
    }
    push @{ $self->{'matchpoints'} }, $matchpoint;
}

=head2 add_simple_matchpoint

  $matcher->add_simple_matchpoint($index, $score, $source_tag,
                            $source_subfields, $source_offset, 
                            $source_length, $source_normalizer);


Adds a simple matchpoint rule -- after composing a key based on the source tag and subfields,
normalized per the normalization fuction, search the index.  All records retrieved
will receive the assigned score.

=cut

sub add_simple_matchpoint {
    my $self = shift;
    my ($index, $score, $source_tag, $source_subfields, $source_offset, $source_length, $source_normalizer) = @_;

    $self->add_matchpoint($index, $score, [
                          { tag => $source_tag, subfields => $source_subfields,
                            offset => $source_offset, 'length' => $source_length,
                            norms => [ $source_normalizer ]
                          }
                         ]);
}

=head2 add_required_check

  $match->add_required_check($source_matchpoint, $target_matchpoint);

Adds a required check definition.  A required check means that in 
order for a match to be considered valid, the key derived from the
source (incoming) record must match the key derived from the target
(already in DB) record.

Unlike a regular matchpoint, only the first repeat of each tag 
in the source and target match criteria are considered.

A typical example of a required check would be verifying that the
titles and publication dates match.

$source_matchpoint and $target_matchpoint are each a reference to
an array of hashes, where each hash follows the same definition
as the matchpoint component specification in add_matchpoint, i.e.,

    tag
    subfields
    offset
    length
    norms

The normalization_rules value should in turn be a reference to an
array, each element of which should be a reference to a 
normalization subroutine (under C4::Normalize) to be applied
to the source string.

=cut

sub add_required_check {
    my $self = shift;
    my ($source_matchpoint, $target_matchpoint) = @_;

    my $matchcheck = {};
    $matchcheck->{'source_matchpoint'}->{'index'} = '';
    $matchcheck->{'source_matchpoint'}->{'score'} = 0;
    $matchcheck->{'source_matchpoint'}->{'components'} = [];
    $matchcheck->{'target_matchpoint'}->{'index'} = '';
    $matchcheck->{'target_matchpoint'}->{'score'} = 0;
    $matchcheck->{'target_matchpoint'}->{'components'} = [];
    foreach my $input_component (@{ $source_matchpoint }) {
        push @{ $matchcheck->{'source_matchpoint'}->{'components'} }, _parse_match_component($input_component);
    }
    foreach my $input_component (@{ $target_matchpoint }) {
        push @{ $matchcheck->{'target_matchpoint'}->{'components'} }, _parse_match_component($input_component);
    }
    push @{ $self->{'required_checks'} }, $matchcheck;
}

=head2 add_simple_required_check

  $matcher->add_simple_required_check($source_tag, $source_subfields,
                $source_offset, $source_length, $source_normalizer, 
                $target_tag, $target_subfields, $target_offset, 
                $target_length, $target_normalizer);

Adds a required check, which requires that the normalized keys made from the source and targets
must match for a match to be considered valid.

=cut

sub add_simple_required_check {
    my $self = shift;
    my ($source_tag, $source_subfields, $source_offset, $source_length, $source_normalizer,
        $target_tag, $target_subfields, $target_offset, $target_length, $target_normalizer) = @_;

    $self->add_required_check(
      [ { tag => $source_tag, subfields => $source_subfields, offset => $source_offset, 'length' => $source_length,
          norms => [ $source_normalizer ] } ],
      [ { tag => $target_tag, subfields => $target_subfields, offset => $target_offset, 'length' => $target_length,
          norms => [ $target_normalizer ] } ]
    );
}

=head2 get_matches

  my @matches = $matcher->get_matches($marc_record, $max_matches);
  foreach $match (@matches) {
      # matches already sorted in order of
      # decreasing score
      print "record ID: $match->{'record_id'};
      print "score:     $match->{'score'};
  }

Identifies all of the records matching the given MARC record.  For a record already 
in the database to be considered a match, it must meet the following criteria:

=over 2

=item 1. Total score from its matching field must exceed the supplied threshold.

=item 2. It must pass all required checks.

=back

Only the top $max_matches matches are returned.  The returned array is sorted
in order of decreasing score, i.e., the best match is first.

=cut

sub get_matches {
    my $self = shift;
    my ($source_record, $max_matches) = @_;

    my $matches = {};
    my $marcframework_used = ''; # use the default framework

    my $QParser;
    $QParser = C4::Context->queryparser if (C4::Context->preference('UseQueryParser'));
    foreach my $matchpoint ( @{ $self->{'matchpoints'} } ) {
        my @source_keys = _get_match_keys( $source_record, $matchpoint );

        next if scalar(@source_keys) == 0;

        # FIXME - because of a bug in QueryParser, an expression ofthe
        # format 'isbn:"isbn1" || isbn:"isbn2" || isbn"isbn3"...'
        # does not get parsed correctly, so we will not
        # do AggressiveMatchOnISBN if UseQueryParser is on
        @source_keys = C4::Koha::GetVariationsOfISBNs(@source_keys)
          if ( $matchpoint->{index} =~ /^isbn$/i
            && C4::Context->preference('AggressiveMatchOnISBN') )
            && !C4::Context->preference('UseQueryParser');

        @source_keys = C4::Koha::GetVariationsOfISSNs(@source_keys)
          if ( $matchpoint->{index} =~ /^issn$/i
            && C4::Context->preference('AggressiveMatchOnISSN') )
            && !C4::Context->preference('UseQueryParser');

        # build query
        my $query;
        my $error;
        my $searchresults;
        my $total_hits;
        if ( $self->{'record_type'} eq 'biblio' ) {

            #NOTE: The QueryParser can't handle the CCL syntax of 'qualifier','qualifier', so fallback to non-QueryParser.
            #NOTE: You can see this in C4::Search::SimpleSearch() as well in a different way.
            if ($QParser && $matchpoint->{'index'} !~ m/\w,\w/) {
                $query = join( " || ",
                    map { "$matchpoint->{'index'}:$_" } @source_keys );
            }
            else {
                my $phr = ( C4::Context->preference('AggressiveMatchOnISBN') || C4::Context->preference('AggressiveMatchOnISSN') )  ? ',phr' : q{};
                $query = join( " OR ",
                    map { "$matchpoint->{'index'}$phr=\"$_\"" } @source_keys );
                    #NOTE: double-quote the values so you don't get a "Embedded truncation not supported" error when a term has a ? in it.
            }

            # Use state variables to avoid recreating the objects every time.
            # With Elasticsearch this also avoids creating a massive amount of
            # ES connectors that would eventually run out of file descriptors.
            state $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::BIBLIOS_INDEX});
            ( $error, $searchresults, $total_hits ) =
              $searcher->simple_search_compat( $query, 0, $max_matches, undef, skip_normalize => 1 );

            if ( defined $error ) {
                warn "search failed ($query) $error";
            }
            else {
                if ( C4::Context->preference('SearchEngine') eq 'Elasticsearch' ) {
                    foreach my $matched ( @{$searchresults} ) {
                        my ( $biblionumber_tag, $biblionumber_subfield ) = C4::Biblio::GetMarcFromKohaField( "biblio.biblionumber", $marcframework_used );
                        my $id = ( $biblionumber_tag > 10 ) ?
                            $matched->field($biblionumber_tag)->subfield($biblionumber_subfield) :
                            $matched->field($biblionumber_tag)->data();
                        $matches->{$id}->{score} += $matchpoint->{score};
                        $matches->{$id}->{record} = $matched;
                    }
                }
                else {
                    foreach my $matched ( @{$searchresults} ) {
                        $matches->{$matched}->{score} += $matchpoint->{'score'};
                        $matches->{$matched}->{record} = $matched;
                    }
                }
            }

        }
        elsif ( $self->{'record_type'} eq 'authority' ) {
            my @marclist;
            my @and_or;
            my @excluding = [];
            my @operator;
            my @value;
            foreach my $key (@source_keys) {
                push @marclist, $matchpoint->{'index'};
                push @and_or,   'or';
                push @operator, 'exact';
                push @value,    $key;
            }
            # Use state variables to avoid recreating the objects every time.
            # With Elasticsearch this also avoids creating a massive amount of
            # ES connectors that would eventually run out of file descriptors.
            state $builder  = Koha::SearchEngine::QueryBuilder->new({index => $Koha::SearchEngine::AUTHORITIES_INDEX});
            state $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::AUTHORITIES_INDEX});
            my $search_query = $builder->build_authorities_query_compat(
                \@marclist, \@and_or, \@excluding, \@operator,
                \@value, undef, 'AuthidAsc'
            );
            my ( $authresults, $total ) = $searcher->search_auth_compat( $search_query, 0, 20 );

            foreach my $result (@$authresults) {
                my $id = $result->{authid};
                $matches->{$id}->{score} += $matchpoint->{'score'};
                $matches->{$id}->{record} = $id;
            }
        }
    }

    # get rid of any that don't meet the threshold
    $matches = { map { ($matches->{$_}->{score} >= $self->{'threshold'}) ? ($_ => $matches->{$_}) : () } keys %$matches };

    my @results = ();
    if ($self->{'record_type'} eq 'biblio') {
        require C4::Biblio;
        # get rid of any that don't meet the required checks
        $matches = {
            map {
                _passes_required_checks( $source_record, $_, $self->{'required_checks'} )
                  ? ( $_ => $matches->{$_} )
                  : ()
            } keys %$matches
        };

        foreach my $id ( keys %$matches ) {
            my $target_record = C4::Search::new_record_from_zebra( 'biblioserver', $matches->{$id}->{record} );
            my $result = C4::Biblio::TransformMarcToKoha( $target_record, $marcframework_used );
            push @results, {
                record_id => $result->{biblionumber},
                score     => $matches->{$id}->{score}
            };
        }
    } elsif ($self->{'record_type'} eq 'authority') {
        require C4::AuthoritiesMarc;
        foreach my $id (keys %$matches) {
            push @results, {
                record_id => $id,
                score     => $matches->{$id}->{score}
            };
        }
    }
    @results = sort {
        $b->{'score'} cmp $a->{'score'} or
        $b->{'record_id'} cmp $a->{'record_id'}
    } @results;
    if (scalar(@results) > $max_matches) {
        @results = @results[0..$max_matches-1];
    }
    return @results;
}

=head2 dump

  $description = $matcher->dump();

Returns a reference to a structure containing all of the information
in the matcher object.  This is mainly a convenience method to
aid setting up a HTML editing form.

=cut

sub dump {
    my $self = shift;
   
    my $result = {};

    $result->{'matcher_id'} = $self->{'id'};
    $result->{'code'} = $self->{'code'};
    $result->{'description'} = $self->{'description'};
    $result->{'record_type'} = $self->{'record_type'};

    $result->{'matchpoints'} = [];
    foreach my $matchpoint (@{ $self->{'matchpoints'} }) {
        push @{  $result->{'matchpoints'} }, $matchpoint;
    }
    $result->{'matchchecks'} = [];
    foreach my $matchcheck (@{ $self->{'required_checks'} }) {
        push @{  $result->{'matchchecks'} }, $matchcheck;
    }

    return $result;
}

sub _passes_required_checks {
    my ($source_record, $target_blob, $matchchecks) = @_;
    my $target_record = MARC::Record->new_from_usmarc($target_blob); # FIXME -- need to avoid parsing record twice

    # no checks supplied == automatic pass
    return 1 if $#{ $matchchecks } == -1;

    foreach my $matchcheck (@{ $matchchecks }) {
        my $source_key = join "", _get_match_keys($source_record, $matchcheck->{'source_matchpoint'});
        my $target_key = join "", _get_match_keys($target_record, $matchcheck->{'target_matchpoint'});
        return 0 unless $source_key eq $target_key;
    }
    return 1;
}

sub _get_match_keys {

    my $source_record = shift;
    my $matchpoint = shift;
    my $check_only_first_repeat = @_ ? shift : 0;

    # If there is more than one component to the matchpoint (e.g.,
    # matchpoint includes both 003 and 001), any repeats
    # of the first component's tag are identified; repeats
    # of the subsequent components' tags are appended to
    # each parallel key dervied from the first component,
    # up to the number of repeats of the first component's tag.
    #
    # For example, if the record has one 003 and two 001s, only
    # one key is retrieved because there is only one 003.  The key
    # will consist of the contents of the first 003 and first 001.
    #
    # If there are two 003s and two 001s, there will be two keys:
    #    first 003 + first 001
    #    second 003 + second 001

    my @keys = ();
    for (my $i = 0; $i <= $#{ $matchpoint->{'components'} }; $i++) {
        my $component = $matchpoint->{'components'}->[$i];
        my $j = -1;
        FIELD: foreach my $field ($source_record->field($component->{'tag'})) {
            $j++;
            last FIELD if $j > 0 and $check_only_first_repeat;
            last FIELD if $i > 0 and $j > $#keys;

            my $string;
            if ( $field->is_control_field() ) {
                $string = $field->data();
            } else {
                $string = $field->as_string(
                    join('', keys %{ $component->{ subfields } }), ' ' # ' ' as separator
                );
            }

            if ($component->{'length'}>0) {
                $string= substr($string, $component->{'offset'}, $component->{'length'});
            } elsif ($component->{'offset'}) {
                $string= substr($string, $component->{'offset'});
            }

            my $norms = $component->{'norms'};
            my $key = $string;

            foreach my $norm ( @{ $norms } ) {
                if ( grep { $norm eq $_ } valid_normalization_routines() ) {
                    if ( $norm eq 'remove_spaces' ) {
                        $key = remove_spaces($key);
                    }
                    elsif ( $norm eq 'upper_case' ) {
                        $key = upper_case($key);
                    }
                    elsif ( $norm eq 'lower_case' ) {
                        $key = lower_case($key);
                    }
                    elsif ( $norm eq 'legacy_default' ) {
                        $key = legacy_default($key);
                    }
                } else {
                    warn "Invalid normalization routine required ($norm)"
                        unless $norm eq 'none';
                }
            }

            if ($i == 0) {
                push @keys, $key if $key;
            } else {
                $keys[$j] .= " $key" if $key;
            }
        }
    }
    return @keys;
}


sub _parse_match_component {
    my $input_component = shift;

    my $component = {};
    $component->{'tag'} = $input_component->{'tag'};
    $component->{'subfields'} = { map { $_ => 1 } split(//, $input_component->{'subfields'}) };
    $component->{'offset'} = exists($input_component->{'offset'}) ? $input_component->{'offset'} : -1;
    $component->{'length'} = $input_component->{'length'} ? $input_component->{'length'} : 0;
    $component->{'norms'} =  $input_component->{'norms'} ? $input_component->{'norms'} : [];

    return $component;
}

sub valid_normalization_routines {

    return (
        'remove_spaces',
        'upper_case',
        'lower_case',
        'legacy_default'
    );
}

1;
__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

Galen Charlton <galen.charlton@liblime.com>

=cut
