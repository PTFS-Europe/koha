use Modern::Perl;

return {
    bug_number => "N/A",
    description => "Set up requirements for testing",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        $dbh->do(q{
            UPDATE systempreferences SET value = 1 WHERE variable="AggressiveMatchOnISBN";
        });
        $dbh->do(q{
            INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('MarcOrderingAutomation', '0', 'NULL', 'Enables automatic order line creation from MARC records', 'YesNo');
        });
        $dbh->do(q{
            UPDATE systempreferences SET value = 'homebranch: 975$a
holdingbranch: 975$b
itype: 975$y
nonpublic_note: 975$x
public_note: 975$z
loc: 975$c
ccode: 975$8
notforloan: 975$7
uri: 975$u
copyno: 975$n
quantity: 975$q
budget_code: 975$h
price: 975$p
replacementprice: 975$v'
            WHERE variable="MarcItemFieldsToOrder";
        });
        $dbh->do(q{
            UPDATE systempreferences SET value = 'price: 975$p
quantity: 975$q
budget_code: 975$h'
            WHERE variable="MarcFieldsToOrder";
        });
        $dbh->do(q{
            INSERT INTO import_batch_profiles (name, matcher_id, overlay_action, nomatch_action, item_action, parse_items, record_type, encoding, format) VALUES ('MARCOrder', 1, 'ignore', 'create_new', 'always_add', 1, 'biblio', 'UTF-8', 'MARCXML')
        });
        $dbh->do(q{
            CREATE TABLE `marc_order_accounts` (
            `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'unique identifier and primary key',
            `description` varchar(250) NOT NULL COMMENT 'description of this account',
            `vendor_id` int(11) DEFAULT NULL COMMENT 'vendor id for this account',
            `budget_id` int(11) DEFAULT NULL COMMENT 'budget id for this account',
            `download_directory` mediumtext DEFAULT NULL COMMENT 'download directory for this account',
            `matcher_id` int(11) DEFAULT NULL COMMENT 'the id of the match rule used (matchpoints.matcher_id)',
            `overlay_action` varchar(50) DEFAULT NULL COMMENT 'how to handle duplicate records',
            `nomatch_action` varchar(50) DEFAULT NULL COMMENT 'how to handle records where no match is found',
            `item_action` varchar(50) DEFAULT NULL COMMENT 'what to do with item records',
            `parse_items` tinyint(1) DEFAULT NULL COMMENT 'should items be parsed',
            `record_type` varchar(50) DEFAULT NULL COMMENT 'type of record in the file',
            `encoding` varchar(50) DEFAULT NULL COMMENT 'file encoding',
            PRIMARY KEY (`id`),
            CONSTRAINT `marc_ordering_account_ibfk_1` FOREIGN KEY (`vendor_id`) REFERENCES `aqbooksellers` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `marc_ordering_account_ibfk_2` FOREIGN KEY (`budget_id`) REFERENCES `aqbudgets` (`budget_id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        });
    },
};
