#!/usr/bin/perl

use Modern::Perl;

use CGI qw ( -utf8 );

use t::lib::Mocks;
use t::lib::TestBuilder;

use Koha::Database;
use Koha::Patrons;

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;

create_patrons( { branchcode => 'CPL' } );
create_patrons( { branchcode => 'FPL' } );
create_patrons( { branchcode => 'MPL' } );
create_patrons( { branchcode => 'TPL' } );
create_patrons( { branchcode => 'FFL' } );

sub _get_patrons_to_load {
    my ($branchcode) = @_;

    my $patrons_to_load = {
        all => {
            details => {
                userid     => "$branchcode" . "all",
                password   => 'Test1234',
                firstname  => $branchcode,
                surname    => 'All_Permissions',
                flags      => 2052,
                branchcode => $branchcode
            },
        },
        manage_budgets => {
            details => {
                userid     => "$branchcode" . "manage_budgets",
                password   => 'Test1234',
                firstname  => $branchcode,
                surname    => 'Manage_Budgets',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 0,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 0,
                'period_manage'     => 1,
                'planning_manage'   => 1,
            }
        },
        manage_funds => {
            details => {
                userid     => "$branchcode" . "manage_funds",
                password   => 'Test1234',
                firstname  => $branchcode,
                surname    => 'Manage_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 1,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 1,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        },
        add_funds => {
            details => {
                userid     => "$branchcode" . "add_funds",
                password   => 'Test1234',
                firstname  => $branchcode,
                surname    => 'Add_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 1,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 0,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        },
        edit_funds => {
            details => {
                userid     => "$branchcode" . "edit_funds",
                password   => 'Test1234',
                firstname  => $branchcode,
                surname    => 'Edit_Funds',
                flags      => 4,
                branchcode => $branchcode
            },
            permissions => {
                'budget_add_del'    => 0,
                'budget_manage_all' => 1,
                'currencies_manage' => 0,
                'budget_manage'     => 1,
                'budget_modify'     => 1,
                'period_manage'     => 0,
                'planning_manage'   => 0,
            }
        }
    };

    my $generic_fields = {
        dateofbirth              => "1990-01-01",
        middle_name              => '',
        othernames               => '',
        categorycode             => 'S',
        dateexpiry               => '2030-04-01',
        password_expiration_date => '2025-01-01',
        lost                     => 0,
        debarred                 => undef,
    };

    foreach my $key ( keys %$patrons_to_load ) {
        my $patron_details = $patrons_to_load->{$key}->{details};
        foreach my $generic_field ( keys %$generic_fields ) {
            $patron_details->{$generic_field} = $generic_fields->{$generic_field};
        }
    }

    return $patrons_to_load;
}

sub create_patrons {
    my ($args) = @_;

    my $branchcode = $args->{branchcode};

    my $patrons = _get_patrons_to_load($branchcode);

    foreach my $record ( keys %$patrons ) {
        my $details     = $patrons->{$record}->{details};
        my $patron      = $builder->build_object( { class => 'Koha::Patrons', value => $details } );
        my $permissions = $patrons->{$record}->{permissions} || {};

        foreach my $permission ( keys %$permissions ) {
            if ( $permissions->{$permission} ) {
                $builder->build(
                    {
                        source => 'UserPermission',
                        value  => {
                            borrowernumber => $patron->borrowernumber,
                            module_bit     => 11,
                            code           => $permission,
                        },
                    }
                );
            }
        }
    }
    warn "Patrons loaded for branch $branchcode";
}

