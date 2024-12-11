#!/usr/bin/perl
#
# Copyright 2024 PTFS Europe Ltd
#
# This file is not part of Koha.
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

use C4::Auth qw( get_template_and_user haspermission );
use C4::Context;
use C4::Output qw( output_html_with_http_headers );

use CGI             qw ( -utf8 );
use List::MoreUtils qw( uniq );

use Koha::Patrons;
use Koha::Libraries;

my $query = CGI->new;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => 'acqui/fund-management.tt',
        query         => $query,
        type          => 'intranet',
        is_plugin     => 1,
    }
);

my $patron    = Koha::Patrons->find( { borrowernumber => $borrowernumber } );
my $userflags = haspermission( $patron->userid );

my $acquisitions_library_groups = Koha::Library::Groups->search( { ft_acquisitions => 1 } );
my @user_library_groups;

# If no library groups are defined then we gather all branches into one "group"
if ( scalar( @{ $acquisitions_library_groups->as_list } == 0 ) ) {
    my @branches  = Koha::Libraries->search()->as_list;
    my $lib_group = {
        title => 'All branches',
        id    => 1,
    };
    my @libraries;
    foreach my $branch (@branches) {
        push( @libraries, $branch->unblessed );
    }
    $lib_group->{libraries} = \@libraries;
    push( @user_library_groups, $lib_group );
}

# Get all acquisitions related library groups
foreach my $alg ( @{ $acquisitions_library_groups->as_list } ) {
    my $lib_group = _map_library_group( { group => $alg } );
    push @user_library_groups, $lib_group;
}

# Get currency data
my $currencies = Koha::Acquisition::Currencies->search()->unblessed;
    my $logged_in_branch = C4::Context::mybranch();

my @permitted_patrons;
my @patrons_with_flags = Koha::Patrons->search( { flags => { '!=' => undef } } )->as_list;

foreach my $patron (@patrons_with_flags) {
    my $userflags = haspermission( $patron->userid );
    if ( $userflags->{acquisition} || $userflags->{superlibrarian} ) {
        my $p = $patron->unblessed;
        $p->{permissions} = $userflags;
        push( @permitted_patrons, $p );
    }
}

if ( scalar( @{ $acquisitions_library_groups->as_list } == 0 ) ) {
    $template->param( permitted_patrons => \@permitted_patrons );
} else {
    my @user_branchcodes = _get_lib_group_branchcodes($logged_in_branch);
    my @permitted_patrons_in_group;
    foreach my $patron (@permitted_patrons) {
        push( @permitted_patrons_in_group, $patron ) if grep( $patron->{branchcode} eq $_, @user_branchcodes );
    }
    $template->param( permitted_patrons => \@permitted_patrons_in_group );
}

$template->param(
    userflags        => $userflags,
    logged_in_branch => { branchcode => C4::Context::mybranch },
    library_groups   => \@user_library_groups,
    currencies       => $currencies
);

output_html_with_http_headers $query, $cookie, $template->output;

sub _map_library_group {
    my ($args) = @_;

    my $group     = $args->{group};
    my $lib_group = {
        title => $group->title,
        id    => $group->id,
    };
    $lib_group->{is_sub_group} = 1 if $args->{sub};
    my @libs_or_sub_groups = Koha::Library::Groups->search( { parent_id => $group->id } )->as_list;

    my @libraries;
    my @sub_groups;
    foreach my $lib (@libs_or_sub_groups) {
        if ( $lib->branchcode ) {
            push( @libraries, $lib->unblessed );
        } else {
            push( @sub_groups, _map_library_group( { group => $lib, sub => 1 } ) );
        }
    }
    $lib_group->{libraries}  = \@libraries;
    $lib_group->{sub_groups} = \@sub_groups;

    $lib_group = _assign_branches_to_parent( { group => $lib_group } );

    return $lib_group;
}

sub _assign_branches_to_parent {
    my ($args) = @_;

    my $group      = $args->{group};
    my $libraries  = $group->{libraries};
    my $sub_groups = $group->{sub_groups};

    if ( !scalar(@$libraries) && scalar(@$sub_groups) ) {
        my @sub_group_libraries;
        foreach my $sub_group (@$sub_groups) {
            if ( !scalar( @{ $sub_group->{libraries} } ) ) {
                $sub_group = _assign_branches_to_parent( { group => $sub_group } );
            }
            push( @sub_group_libraries, @{ $sub_group->{libraries} } );
        }
        my @parent_branches;
        foreach my $library (@sub_group_libraries) {
            push( @parent_branches, $library )
                unless grep( $_->{branchcode} eq $library->{branchcode}, @parent_branches );
        }
        $group->{libraries} = \@parent_branches;
    }
    return $group;
}

sub _get_lib_group_branchcodes {
    my ($logged_in_branch) = @_;

    my $branch         = Koha::Libraries->find( { branchcode => $logged_in_branch } );
    my $library_groups = $branch->library_groups;

    my @branchcodes;

    foreach my $group ( @{ $library_groups->as_list } ) {
        my @libs_or_sub_groups = Koha::Library::Groups->search( { parent_id => $group->parent_id } )->as_list;
        foreach my $lib (@libs_or_sub_groups) {
            if ( $lib->branchcode ) {
                push( @branchcodes, $lib->branchcode ) unless grep( $_ eq $lib->branchcode, @branchcodes );
            }
        }
    }
    return @branchcodes;
}
