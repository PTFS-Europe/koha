use Modern::Perl;

return {
    bug_number => "DEV ONLY - DELETE THIS FILE LATER",
    description => "Sample data for ERM Usage Statistics",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT INTO erm_platforms (erm_platform_id, name, description) VALUES
                (1,"platform_name","platform_description")
            }
        );

        $dbh->do(
            q{
                INSERT INTO erm_harvesters (erm_harvester_id, platform_id, status, method, aggregator, service_type, service_url, report_release, harvest_start, harvest_end, customer_id, requestor_id, api_key, platform, requestor_name, requestor_email) VALUES
                (1,1,"test","test","test_aggregator", "test_service_type", "https://serviceurl.com/", "test_report_release", "2023-03-01", "2023-03-02", 1, 1, "test_api_key", "test_platform", "test_requestor_name", "test_requestor_email")
            }
        );

        
    },
};
