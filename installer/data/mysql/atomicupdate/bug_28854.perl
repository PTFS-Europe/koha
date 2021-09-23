use Modern::Perl;

return {
    bug_number => "28854",
    description => "Item bundles support",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};

        if( !TableExists( 'item_bundles' ) ) {
            $dbh->do(q{
                CREATE TABLE `item_bundles` (
                  `item` int(11) NOT NULL,
                  `host` int(11) NOT NULL,
                  PRIMARY KEY (`host`, `item`),
                  UNIQUE KEY `item_bundles_uniq_1` (`item`),
                  CONSTRAINT `item_bundles_ibfk_1` FOREIGN KEY (`item`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `item_bundles_ibfk_2` FOREIGN KEY (`host`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            });
        }
        say $out "item_bundles table added";

        if( !TableExists( 'items_lost_issue' ) ) {
            $dbh->do(q{
                CREATE TABLE `items_lost_issue` (
                  `id` int(11) NOT NULL AUTO_INCREMENT,
                  `itemnumber` int(11) NOT NULL,
                  `issue_id` int(11) DEFAULT NULL,
                  `created_on` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                  PRIMARY KEY (`id`),
                  UNIQUE KEY `itemnumber` (`itemnumber`),
                  KEY `issue_id` (`issue_id`),
                  CONSTRAINT `items_lost_issue_ibfk_1` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
                  CONSTRAINT `items_lost_issue_ibfk_2` FOREIGN KEY (`issue_id`) REFERENCES `old_issues` (`issue_id`) ON DELETE SET NULL ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            });
        }
        say $out "items_list_issue table added";

        my ($lost_val) = $dbh->selectrow_array( "SELECT MAX(authorised_value) FROM authorised_values WHERE category = 'LOST'", {} );
        $lost_val++;

        $dbh->do(qq{
           INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOST',$lost_val,'Missing from bundle')
        });
        say $out "Missing from bundle LOST AV added";

        my ($nfl_val) = $dbh->selectrow_array( "SELECT MAX(authorised_value) FROM authorised_values WHERE category = 'NOT_LOAN'", {} );
        $nfl_val++;

        $dbh->do(qq{
           INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('NOT_LOAN',$nfl_val,'Added to bundle')
        });
        say $out "Added to bundle NOT_LOAN AV added";

        $dbh->do(qq{
            INSERT IGNORE INTO systempreferences( `variable`, `value`, `options`, `explanation`, `type` )
            VALUES
              ( 'BundleLostValue', $lost_val, '', 'Sets the LOST AV value that represents "Missing from bundle" as a lost value', 'Free' ),
              ( 'BundleNotLoanValue', $nfl_val, '', 'Sets the NOT_LOAN AV value that represents "Added to bundle" as a not for loan value', 'Free')
        });
        say $out "System preferences added and set";
    }
}
