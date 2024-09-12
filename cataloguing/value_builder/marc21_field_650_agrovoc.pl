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
use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );

my $builder = sub {
    my ( $params ) = @_;
    my $function_name = $params->{id};
    my $res = "
<script>
    function Click$function_name(ev) {
        ev.preventDefault();
        var button = ev.target;
        var liElement = button.closest('li[id^=\"tag_\"]');
        var liId = liElement.id;
        window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=marc21_field_650_agrovoc.pl&popup&li_id=\"+encodeURIComponent(liId),\"agrovoc\",\"width=500,height=400,toolbar=false,scrollbars=yes\");
    }
</script>
";
    return $res;
};

my $launcher = sub {
    my ( $params ) = @_;
    my $cgi = $params->{cgi};
    my $results_per_page = 30;
    my $current_page = $cgi->param('page') || 1;

    my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
        {   template_name   => "cataloguing/value_builder/marc21_field_650_agrovoc.tt",
            query           => $cgi,
            type            => "intranet",
            flagsrequired   => { catalogue => 1 },
        }
    );

    output_html_with_http_headers $cgi, $cookie, $template->output;
};

return { builder => $builder, launcher => $launcher };
