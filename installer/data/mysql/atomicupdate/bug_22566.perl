$DBversion = 'XXX';
if ( CheckVersion($DBversion) ) {
    $dbh->do(q{UPDATE letter SET content = 'Stockrotation report for [% name %]:\r\n\r\n[%- IF items.size -%]\r\n[% items.size %] items to be processed for this branch.\r\n[%- ELSE -%]\r\nNo items to be processed for this branch\r\n[%- END -%]\r\n\r\n\r\n[%- FOREACH item IN items -%]\r\n[% IF item.reason != ''in-demand'' %]\r\nTitle: [% item.title %]\r\nAuthor: [% item.author %]\r\nCallnumber: [% item.callnumber %]\r\nLocation: [% item.location %]\r\nBarcode: [% item.barcode %]\r\nOn loan?: [% item.onloan %]\r\nStatus: [% item.reason %]\r\nCurrent Library: [% item.branch.branchname %] [% item.branch.branchcode %]\r\n[% END %]\r\n[%- END -%]' WHERE code = 'SR_SLIP'});

    SetVersion($DBversion);
    print "Upgrade to $DBversion done (Bug XXXXX - description)\n";
}
