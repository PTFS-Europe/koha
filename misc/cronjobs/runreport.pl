#!/usr/bin/perl
#
# Copyright 2008 Liblime
# Copyright 2014 Foundations Bible College, Inc.
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

use C4::Reports::Guided; # 0.12
use Koha::Reports;
use C4::Context;
use C4::Log;
use Koha::Email;
use Koha::DateUtils;

use Getopt::Long qw(:config auto_help auto_version);
use Pod::Usage;
use MIME::Lite;
use Text::CSV::Encoded;
use CGI qw ( -utf8 );
use Carp;
use Encode;
use JSON qw( to_json );

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

=head1 NAME

runreport.pl - Run pre-existing saved reports

=head1 SYNOPSIS

runreport.pl [ -h | -m ] [ -v ] reportID [ reportID ... ]

 Options:
   -h --help       brief help message
   -m --man        full documentation, same as --help --verbose
   -v --verbose    verbose output

   --format=s      selects format. Choice of text, html, csv or tsv

   -e --email      whether to use e-mail (implied by --to or --from)
   -a --attachment additionally attach the report as a file. cannot be used with html format
   --username      username to pass to the SMTP server for authentication
   --password      password to pass to the SMTP server for authentication
   --method        method is the type of authentication. Ie. LOGIN, DIGEST-MD5, etc.
   --to=s          e-mail address to send report to
   --from=s        e-mail address to send report from
   --subject=s     subject for the e-mail
   --store-results store the result of the report
   --csv-header    add column names as first line of csv output


 Arguments:
   reportID        report ID Number from saved_sql.id, multiple ID's may be specified

=head1 OPTIONS

=over

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<-v>

Verbose. Without this flag set, only fatal errors are reported.

=item B<--format>

Current options are text, html, csv, and tsv. At the moment, text and tsv both produce tab-separated tab-separated output.

=item B<--email>

Whether to use e-mail (implied by --to or --from).

=item B<--username>

Username to pass to the SMTP server for authentication

=item B<--password>

Password to pass to the SMTP server for authentication

=item B<--method>

Method is the type of authentication. Ie. LOGIN, DIGEST-MD5, etc.

=item B<--to>

E-mail address to send report to. Defaults to KohaAdminEmailAddress.

=item B<--from>

E-mail address to send report from. Defaults to KohaAdminEmailAddress.

=item B<--subject>

Subject for the e-mail message. Defaults to "Koha Saved Report"

=item B<--store-results>

Store the result of the report into the saved_reports DB table.

To access the results, go on Reports > Guided reports > Saved report.

=back

=head1 DESCRIPTION

This script is designed to run existing Saved Reports.

=head1 USAGE EXAMPLES

B<runreport.pl 16>

In the most basic form, runs the report specified by ID number from 
saved_sql.id, in this case #16, outputting the results to STDOUT.  

B<runreport.pl 16 17>

Same as above, but also runs report #17. 

=head1 TO DO

=over


=item *

Allow Saved Results option.


=back

=head1 SEE ALSO

Reports - Guided Reports

=cut

# These variables can be set by command line options,
# initially set to default values.

my $help    = 0;
my $man     = 0;
my $verbose = 0;
my $email   = 0;
my $attachment = 0;
my $format  = "text";
my $to      = "";
my $from    = "";
my $subject = "";
my $separator = ',';
my $quote = '"';
my $store_results = 0;
my $csv_header = 0;

my $username = undef;
my $password = undef;
my $method = 'LOGIN';

GetOptions(
    'help|?'            => \$help,
    'man'               => \$man,
    'verbose'           => \$verbose,
    'format=s'          => \$format,
    'to=s'              => \$to,
    'from=s'            => \$from,
    'subject=s'         => \$subject,
    'email'             => \$email,
    'a|attachment'      => \$attachment,
    'username:s'        => \$username,
    'password:s'        => \$password,
    'method:s'          => \$method,
    'store-results'     => \$store_results,
    'csv-header'        => \$csv_header,

) or pod2usage(2);
pod2usage( -verbose => 2 ) if ($man);
pod2usage( -verbose => 2 ) if ($help and $verbose);
pod2usage(1) if $help;

cronlogaction();

unless ($format) {
    $verbose and print STDERR "No format specified, assuming 'text'\n";
    $format = 'text';
}

if ($format eq 'tsv' || $format eq 'text') {
    $format = 'csv';
    $separator = "\t";
}

if ($to or $from or $email) {
    $email = 1;
    $from or $from = C4::Context->preference('KohaAdminEmailAddress');
    $to   or $to   = C4::Context->preference('KohaAdminEmailAddress');
}

unless (scalar(@ARGV)) {
    print STDERR "ERROR: No reportID(s) specified\n";
    pod2usage(1);
}
($verbose) and print scalar(@ARGV), " argument(s) after options: " . join(" ", @ARGV) . "\n";

my $today = dt_from_string();
my $date = $today->ymd();

foreach my $report_id (@ARGV) {
    my $report = Koha::Reports->find( $report_id );
    unless ($report) {
        warn "ERROR: No saved report $report_id found";
        next;
    }
    my $sql         = $report->savedsql;
    my $report_name = $report->report_name;
    my $type        = $report->type;

    $verbose and print "SQL: $sql\n\n";
    if ( $subject eq "" )
    {
        if ( defined($report_name) and $report_name ne "")
        {
            $subject = $report_name ;
        }
        else
        {
            $subject = 'Koha Saved Report';
        }
    }
    my ($sth) = execute_query( $sql, undef, undef, undef, $report_id );
    my $count = scalar($sth->rows);
    unless ($count) {
        print "NO OUTPUT: 0 results from execute_query\n";
        next;
    }
    $verbose and print "$count results from execute_query\n";

    my $message;
    my @rows_to_store;
    if ($format eq 'html') {
        my $cgi = CGI->new();
        my @rows;
        while (my $line = $sth->fetchrow_arrayref) {
            foreach (@$line) { defined($_) or $_ = ''; }    # catch undef values, replace w/ ''
            push @rows, $cgi->TR( join('', $cgi->td($line)) ) . "\n";
            push @rows_to_store, [@$line] if $store_results;
        }
        $message = $cgi->table(join "", @rows);
    } elsif ($format eq 'csv') {
        my $csv = Text::CSV::Encoded->new({
            encoding_out => 'utf8',
            binary      => 1,
            quote_char  => $quote,
            sep_char    => $separator,
            });

        if ( $csv_header ) {
            my @fields = map { decode( 'utf8', $_ ) } @{ $sth->{NAME} };
            $csv->combine( @fields );
            $message .= $csv->string() . "\n";
            push @rows_to_store, [@fields] if $store_results;
        }

        while (my $line = $sth->fetchrow_arrayref) {
            $csv->combine(@$line);
            $message .= $csv->string() . "\n";
            push @rows_to_store, [@$line] if $store_results;
        }
    }
    if ( $store_results ) {
        my $json = to_json( \@rows_to_store );
        C4::Reports::Guided::store_results( $report_id, $json );
    }
    if ($email) {
        my $args = { to => $to, from => $from, subject => $subject };
        if ( $format eq 'html' ) {
            $message = "<html><head><style>tr:nth-child(2n+1) { background-color: #ccc;}</style></head><body>$message</body></html>";
            $args->{contenttype} = 'text/html';
        }
        my $email = Koha::Email->new();
        my %mail  = $email->create_message_headers($args);
        $mail{Data} = $message;
        $mail{Auth} = { user => $username, pass => $password, method => $method } if $username;

        my $msg = MIME::Lite->new(%mail);

        $msg->attach(
            Type        => "text/$format",
            Data        => encode( 'utf8', $message ),
            Filename    => "report$report_id-$date.$format",
            Disposition => 'attachment',
        ) if $attachment;

        $msg->send();
        carp "Mail not sent" unless $msg->last_send_successful();
    }
    else {
        print $message;
    }
}
