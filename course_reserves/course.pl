#!/usr/bin/perl

#
# Copyright 2012 Bywater Solutions
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

use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Koha   qw( GetAuthorisedValues );

use C4::CourseReserves qw( GetCourse );

my $cgi = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => "course_reserves/course.tt",
        query         => $cgi,
        type          => "intranet",
        flagsrequired => { coursereserves => 'manage_courses' },
    }
);

my $course_id = $cgi->param('course_id');

if ($course_id) {
    my $course = GetCourse($course_id);
    $template->param(%$course);
}

$template->param(
    departments => GetAuthorisedValues('DEPARTMENT'),
    terms       => GetAuthorisedValues('TERM'),
);

output_html_with_http_headers $cgi, $cookie, $template->output;
