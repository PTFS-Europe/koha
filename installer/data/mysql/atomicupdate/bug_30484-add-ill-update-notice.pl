$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{INSERT IGNORE INTO letter(module, code, branchcode, name, is_html, title, contVent, message_transport_type, lang) VALUES ('ill', 'ILL_REQUEST_UPDATE', '', 'ILL request update', 0, "Interlibrary loan request update", "Dear [% borrower.firstname %] [% borrower.surname %],\n\nThe Interlibrary loans request number [% illrequest.illrequest_id %] you placed for\n\n- [% ill_bib_title %] - [% ill_bib_author %]\n\nhas been updated\n\nDetails of the update are below:\n\n[% additional_text %]\n\nKind Regards\n\n[% branch.branchname %]\n[% branch.branchaddress1 %]\n[% branch.branchaddress2 %]\n[% branch.branchaddress3 %]\n[% branch.branchcity %]\n[% branch.branchstate %]\n[% branch.branchzip %]\n[% branch.branchphone %]\n[% branch.branchillemail %]\n[% branch.branchemail %]", 'email', 'default');});
    $dbh->do(q{INSERT IGNORE INTO letter(module, code, branchcode, name, is_html, title, content, message_transport_type, lang) VALUES ('ill', 'ILL_REQUEST_UPDATE', '', 'ILL request update', 0, "Interlibrary loan request update", "Dear [% borrower.firstname %] [% borrower.surname %],\n\nThe Interlibrary loans request number [% illrequest.illrequest_id %] you placed for\n\n- [% ill_bib_title %] - [% ill_bib_author %]\n\nhas been updated\n\nDetails of the update are below:\n\n[% additional_text %]\n\nKind Regards\n\n[% branch.branchname %]\n[% branch.branchaddress1 %]\n[% branch.branchaddress2 %]\n[% branch.branchaddress3 %]\n[% branch.branchcity %]\n[% branch.branchstate %]\n[% branch.branchzip %]\n[% branch.branchphone %]\n[% branch.branchillemail %]\n[% branch.branchemail %]", 'sms', 'default');});
    $dbh->do(q{INSERT IGNORE INTO message_attributes (message_name, takes_days) VALUES ('Ill_update', 0);});
    my $ready_id = $dbh->last_insert_id(undef, undef, 'message_attributes', undef);
    if (defined $ready_id) {
        $dbh->do(qq(INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES ($ready_id, 'email', 0, 'ill', 'ILL_REQUEST_UPDATE');));
        $dbh->do(qq(INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES ($ready_id, 'sms', 0, 'ill', 'ILL_REQUEST_UPDATE');));
        $dbh->do(qq(INSERT IGNORE INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES ($ready_id, 'phone', 0, 'ill', 'ILL_REQUEST_UPDATE');));
    }

    NewVersion( $DBversion, "30484", "Bug 30484 - Add a notice template for ILL Update notices");
}
