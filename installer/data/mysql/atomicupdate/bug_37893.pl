use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);
use C4::SIP::Sip::Configuration;

return {
    bug_number  => "37893",
    description => "Move SIPconfig.xml to database",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my $sip_instances = qx/koha-list --sip/;

        if( ! $sip_instances ) {
            say_info( $out, "No SIP instances found. Skipping." );
            return;
        }

        foreach my $sip_instance ( $sip_instances ) {

            $sip_instance =~ s/\n//g;
            my $SIPconfig = "/etc/koha/sites/$sip_instance/SIPconfig.xml";
            say_info( $out, "Reading SIPconfig.xml for $sip_instance located at $SIPconfig" );
            
            my $config = C4::SIP::Sip::Configuration->new( $SIPconfig );
            my @institution_keys = keys %{$config->{institutions}};

            foreach my $institution_key ( @institution_keys ) {
                my $insert_sth = $dbh->prepare(
                    q{INSERT IGNORE INTO sip_institutions (name, implementation, checkin, checkout, offline, renewal, retries, status_update, timeout) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)}
                );

                my $implementation = $config->{institutions}->{$institution_key}->{implementation} // 'ILS';
                my $checkin = $config->{institutions}->{$institution_key}->{policy}->{checkin} // 'true';
                my $checkout = $config->{institutions}->{$institution_key}->{policy}->{checkout} // 'true';
                my $offline = $config->{institutions}->{$institution_key}->{policy}->{offline} // 'false';
                my $renewal = $config->{institutions}->{$institution_key}->{policy}->{renewal} // 'false';
                my $retries = $config->{institutions}->{$institution_key}->{policy}->{retries} // 5;
                my $status_update = $config->{institutions}->{$institution_key}->{policy}->{status_update} // 'false';
                my $timeout = $config->{institutions}->{$institution_key}->{policy}->{timeout} // 100;

                $insert_sth->execute(
                    $institution_key,
                    $implementation,
                    $checkin eq 'false' ? 0 : 1,
                    $checkout eq 'false' ? 0 : 1,
                    $offline eq 'true' ? 1 : 0,
                    $renewal eq 'true' ? 1 : 0,
                    $retries,
                    $status_update eq 'true' ? 1 : 0,
                    $timeout,
                );
            }
        }
    },
};
