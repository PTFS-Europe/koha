use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "28575",
    description =>
        "Add a syspref to prevent refunds on lost items if the fee was paid more than a set number of days ago",
    up => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # Do you stuffs here
        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('NoRefundOnLostFinesPaidAge','','','Do not refund lost item fees if the fee was paid off more than this number of days ago','Integer')
            }
        );
        say_success( $out, "Successfully added new system preference: NoRefundOnLostFinesPaidAge" );
    },
};
