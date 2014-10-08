package C4::ILL;

# Copyright 2012 Mark Gavillet & PTFS Europe
# Copyright 2014 PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use DateTime;
use Mail::Sendmail;
use Carp;
use C4::Context;
use C4::Koha qw( GetAuthorisedValues );
use C4::Members qw( GetMemberDetails);
use C4::Branch qw( GetBranchName );
use base qw(Exporter);

our $VERSION = 3.10.02.000;
our @EXPORT  = ();

our @EXPORT_OK = qw(
  UpdateILLRequest
  GetILLAuthValues
  LogILLRequest
  GetAllILL
  GetILLRequest
  DeleteILLRequest
);

=heading4 UpdateILLRequest

    $rows = UpdateILLRequest( $req_hashref );

Passed a hashref of ill request fields returns the number of
rows updated ( should be 1 ) or undef on error

=cut

sub UpdateILLRequest {
    my $req = shift;
    if ( $req->{requestid} ) {
        my $stmt = <<"END_STMT";
update illrequest set biblionumber=?, status=?, title=?,
author_editor=?, journal_title=?, publisher=?, issn=?,
year=?, season=?, month=?, day=?, volume=?, part=?,
issue=?, special_issue=?, article_title=?, author_names=?,
pages=?, notes=?, conference_title=?, conference_author=?,
conference_venue=?, conference_date=?, isbn=?,
edition=?, chapter_title=?, composer=?, ismn=?, university=?,
dissertation=?, scale=?, shelfmark=?,
commercial_use=?, needed_by=?, local1=?, local2=?, local3=?
where requestid=?
END_STMT
        my $dbh = C4::Context->dbh;
        return $dbh->do(
            $stmt, {},
            $req->{biblionumber},      $req->{status},
            $req->{title},             $req->{author},
            $req->{journal_title},     $req->{publisher},
            $req->{issn},              $req->{year},
            $req->{season},            $req->{month},
            $req->{day},               $req->{volume},
            $req->{part},              $req->{issue},
            $req->{special_issue},     $req->{article_title},
            $req->{author_names},      $req->{pages},
            $req->{notes},             $req->{conference_title},
            $req->{conference_author}, $req->{conference_venue},
            $req->{conference_date},   $req->{isbn},
            $req->{edition},           $req->{chapter_title},
            $req->{composer},          $req->{ismn},
            $req->{university},        $req->{dissertation},
            $req->{scale},             $req->{shelfmark},
            $req->{commercial_use},    $req->{needed_by},
            $req->{local1},            $req->{local2},
            $req->{local3},            $req->{requestid}
        );
    }
    carp 'UpdateILLRequest called without a requestid';
    return;
}

sub DeleteILLRequest {
    my $requestid = shift;
    my $dbh       = C4::Context->dbh;
    return $dbh->do( 'delete from illrequest where requestid=?',
        {}, $requestid );
}

sub GetILLRequest {
    my $requestid = shift;
    if ($requestid) {
        my $dbh    = C4::Context->dbh;
        my $tuples = $dbh->selectall_arrayref(
            'select * from illrequest where requestid=?',
            { Slice => {} }, $requestid );
        return shift @{$tuples};
    }
    return;
}

sub _opac_fmt_req {
    my $r          = shift;
    my $ill_prefix = C4::Context->preference('ILLRequestPrefix');
    $r->{ref} = FormatILLReference($r);
    if ( $r->{status} ) {
        $r->{status_code} = $r->{status};
        my $status = GetAuthorisedValues( 'ILLSTATUS', $r->{status}, 'opac' );
        my @opac_status = grep { $_->{selected} == 1 } @{$status};
        if (@opac_status) {
            $r->{status} = $opac_status[0]->{lib};
        }
    }
    if ( $r->{request_type} ) {
        my $req_labels =
          GetAuthorisedValues( 'ILLTYPE', $r->{request_type}, 'opac' );
        my @rl = grep { $_->{selected} == 1 } @{$req_labels};
        if (@rl) {
            $r->{request_type_label} = $rl[0]->{lib};
        }
    }
    $r->{requestnumber} = "$ill_prefix$r->{requestnumber}";
    $r->{branchname}    = GetBranchName( $r->{orig_branch} );
    if ( $r->{borrowernumber} ) {
        my $b = GetMemberDetails( $r->{borrowernumber} );
        $r->{borrower_surname}  = $b->{surname};
        $r->{borrower_showname} = $b->{showname};
    }

    return $r;
}

sub GetAllILL {
    my $return_type = shift;
    my $dbh         = C4::Context->dbh;
    my $ill_prefix  = C4::Context->preference('ILLRequestPrefix');

    my @bind_values;
    my $stmt = {
        ALL => 'select * from illrequest order by date_placed asc',
        NEW =>
          'select * from illrequest where status=? order by date_placed asc',
        COMPLETED =>
'select * from illrequest where completed_date is not null order by date_placed asc',
        OPENNOTNEW =>
'select * from illrequest where completed_date is null and status<>? order by date_placed asc',
    };
    if ( $return_type =~ m/NEW/sm ) {    #NEW || OPENNOTNEW
        push @bind_values, C4::Context->preference('ILLNewRequestStatus');
    }
    if ( $stmt->{$return_type} ) {
        my $requests =
          $dbh->selectall_arrayref( $stmt->{$return_type}, { Slice => {} },
            @bind_values );
        my @formatted_reqs = map { _opac_fmt_req($_); } @{$requests};
        return \@formatted_reqs;
    }
    carp "GetAllILL called with invalid type:$return_type";
    return;
}

sub _get_req_from_cgi {
    my $q = shift;

    my $r = {};
    my @fields =
      qw( borrowernumber biblionumber status date_placed reply_date completed_date
      request_type orig_branch service_branch title author_editor journal_title
      publisher issn year season month day volume part issue special_issue
      article_title author_names pages notes conference_title conference_author
      conference_venue conference_date isbn edition chapter_title composer ismn
      university dissertation scale identifier shelfmark local1 local2 local3
      commercial_use needed_by );

    for my $label (@fields) {
        $r->{$label} = $q->param($label);
    }
    return $r;
}

sub LogILLRequest {
    my ( $borrowernumber, $query ) = @_;
    my $borrower = GetMemberDetails($borrowernumber);
    my $req      = _get_req_from_cgi($query);
    $req->{status}         = C4::Context->preference('ILLNewRequestStatus');
    $req->{date_placed}    = DateTime->today->ymd();
    $req->{borrowernumber} = $borrowernumber;
    $req->{service_branch} = $req->{orig_branch} = $borrower->{branchcode};
    my $submitted_request = _insert_ill_request($req);

    if ( C4::Context->preference('ILLEmailNotify') == 1 ) {
        SendILLNotification( $borrowernumber, $submitted_request,
            $borrower->{email} );
    }
    return $submitted_request;
}

sub _insert_ill_request {
    my $r      = shift;
    my $dbh    = C4::Context->dbh;
    my $prefix = C4::Context->preference('ILLRequestPrefix');
    my ( $sql, @values ) = _write_insert_stmt($r);
    $dbh->do( $sql, {}, @values );
    my $reqno = $dbh->{mysql_insert_id};
    return "$prefix$reqno";
}

sub _write_insert_stmt {
    my $r = shift;
    my @insert_fields = grep { defined $r->{$_} } keys %{$r};

    my $stmt = 'insert into illrequest ( ' . join ', ', @insert_fields;
    my $placeholders = '?' x @insert_fields;
    $placeholders =~ s/\?\?/?,?/g;
    $stmt .= " ) values ( $placeholders )";
    my @values = map { $r->{$_} } @insert_fields;
    return ( $stmt, @values );
}

sub SendILLNotification {
    my ( $borrowernumber, $submitted_request, $borrower_email ) = @_;
    my %mail = (
        To      => $borrower_email,
        From    => C4::Context->preference('KohaAdminEmailAddress'),
        Subject => 'Inter-Library Loan Request ' . $submitted_request,
        Message =>
"Your Inter-Library Loan request was successfully placed. Your reference number is $submitted_request",
    );
    sendmail(%mail);
    return;
}

sub GetILLAuthValues {
    my $authval_type = shift;
    my $dbh          = C4::Context->dbh;
    return $dbh->selectall_arrayref(
'select authorised_value,lib,id from authorised_values where category=? order by lib asc',
        { Slice => {} },
        $authval_type
    );
}

sub FormatILLReference {
    my $req = shift;
    my $ref;
    if ( $req->{request_type} eq 'ILLBOOK' ) {
        if ( $req->{chapter_title} ) {
            $ref = $req->{author_names} . ', ' . $req->{chapter_title};
            if ( $req->{isbn} ) {
                $ref .= ' (' . $req->{isbn} . ')';
            }
            $ref .= '<br />in ' . $req->{title};
        }
        else {
            $ref = $req->{title};
            if ( $req->{isbn} ) {
                $ref .= ' (' . $req->{isbn} . ')';
            }
            $ref .= '<br />';
            $ref .= $req->{author_editor};
        }
    }
    elsif ( $req->{request_type} eq 'ILLJOURNAL' ) {
        if ( $req->{article_title} ) {
            $ref = $req->{author_names} . ', ' . $req->{article_title};
            $ref .= '<br />in ' . $req->{journal_title};
            if ( $req->{issue} ) {
                $ref .= ', Issue ' . $req->{issue};
            }
            if ( $req->{volume} ) {
                $ref .= ', Vol. ' . $req->{volume};
            }
            if ( $req->{pages} ) {
                $ref .= '<br />Pages ' . $req->{pages};
            }
        }
        else {
            $ref = $req->{journal_title};
            if ( $req->{issue} ) {
                $ref .= ', Issue ' . $req->{issue};
            }
            if ( $req->{volume} ) {
                $ref .= ', Vol. ' . $req->{volume};
            }
        }
    }
    elsif ( $req->{request_type} eq 'ILLTHESIS' ) {
        if ( $req->{chapter_title} ) {
            $ref =
                $req->{author_editor} . ', '
              . $req->{chapter_title}
              . '<br />in '
              . $req->{title} . ' - '
              . $req->{university} . ', '
              . $req->{dissertation};
        }
        else {
            $ref =
                $req->{title} . ', '
              . $req->{author_editor} . ' - '
              . $req->{university} . ', '
              . $req->{dissertation};
        }
    }
    elsif ( $req->{request_type} eq 'ILLOTHER' ) {
        $ref = $req->{title};
        if ( $req->{author_editor} ) {
            $ref .= ', ' . $req->{author_editor};
        }
        if ( $req->{composer} ) {
            $ref .= ', ' . $req->{composer};
        }
    }
    return $ref;
}

1;
