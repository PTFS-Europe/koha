$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {

    # Uncomment to run
    return 1;

    # Move cash_tills to cash_registers
    $dbh->do( "UPDATE cash_till SET branch = 'ZZZ' WHERE branch is NULL;" );
    $dbh->do( "INSERT IGNORE INTO cash_registers (id, name, description, branch, starting_float, archived) SELECT tillid, name, description, branch, starting_float, archived FROM cash_till ORDER BY tillid ASC;" );

    # Update debit_types from cash_transcodes
    $dbh->do( "UPDATE account_debit_types, cash_transcode SET account_debit_types.description = cash_transcode.description, account_debit_types.archived = cash_transcode.archived, account_debit_types.can_be_sold = cash_transcode.visible_charge WHERE account_debit_types.code = cash_transcode.code;" );
    $dbh->do( "INSERT INTO account_debit_types (code, description, archived, can_be_sold) SELECT code, description, archived, visible_charge FROM cash_transcode WHERE code NOT IN (SELECT code FROM account_debit_types) ORDER BY code ASC;" );

    # Migrate CASHUP actions from cash_transaction to cash_register_action
    $dbh->do( "INSERT INTO cash_register_actions (code, register_id, manager_id, amount, timestamp) SELECT tcode, till, '589840', amt, created FROM cash_transaction WHERE tcode = 'CASHUP';" );

    # Update accountlines and account_offsets from cash_transactions
    $dbh->do( "INSERT IGNORE INTO cash_transcode (code, description) VALUES ('OVERDUE', 'Fine');" );
    $dbh->do( "UPDATE cash_transaction SET tcode = 'OVERDUE' WHERE tcode = 'FINE';" );

    #  SELECT accountlines_id, id, accountlines.borrowernumber, debit_type_code, status, till, receiptid, paymenttype, date, timestamp, created FROM accountlines JOIN cash_transaction ON accountlines.date = date(cash_transaction.created) AND accountlines.debit_type_code = cash_transaction.tcode AND accountlines.amount = cash_transaction.amt WHERE receiptid IS NOT NULL LIMIT 25;

    # Try walking the cash_transactions and for each one look for a match in accountlines using:
    #  * date(cash_transaction.created) = accountlines.date AND cash_transaction.tcode = accountlines.debit_type_code AND cash_transaction.amt = accountlines.amount AND accountlines.register_id IS NULL
    #  * sorted on accountlines date
    #  * fill in accountlines.register_id = cash_transaction.till_id
    #  * add a new anonymous accounline when a match is not found at all?
    # What about receiptid's?
    # What about account_offsets?

    my $sth = $dbh->prepare(qq{ SELECT date(timestamp) AS date, timestamp, user, object, info from action_logs WHERE module = 'FINES' AND action = 'CREATE' AND info LIKE "%'action' => 'create_payment'%" ORDER BY timestamp DESC LIMIT 10000 });
    my $sth1 = $dbh->prepare(qq{ SELECT * FROM accountlines WHERE date = ? AND manager_id = ? AND borrowernumber = ? AND register_id IS NULL AND credit_type_code = 'Pay' });
    #my $sth1 = $dbh->prepare(qq{ SELECT * FROM accountlines WHERE date = ? AND manager_id = ? AND borrowernumber = ? AND credit_type_code = 'Pay' });
    my $sth1_count = $dbh->prepare(qq{ SELECT COUNT(*) AS count FROM (SELECT * FROM accountlines WHERE date = ? AND manager_id = ? AND borrowernumber = ? AND register_id IS NULL AND credit_type_code = 'Pay') AS T });
    #my $sth1_count = $dbh->prepare(qq{ SELECT COUNT(*) AS count FROM (SELECT * FROM accountlines WHERE date = ? AND manager_id = ? AND borrowernumber = ? AND credit_type_code = 'Pay') AS T });
    my $sth2 = $dbh->prepare(qq{SELECT SUM(amt) AS amount, till, created FROM cash_transaction WHERE created = ? GROUP BY till, created});
    my $sth3 = $dbh->prepare(qq{UPDATE accountlines SET register_id = ?, timestamp = ? WHERE accountlines_id = ?});
    my $sth4 = $dbh->prepare(qq{INSERT IGNORE INTO account_offsets ( credit_id, debit_id, type, amount, created_on ) VALUES (?, ?, 'Payment', ?, ? )});

    $sth->execute();
    use Data::Undumper;
    while ( my $row = $sth->fetchrow_hashref ) {
        my $timestamp = $row->{timestamp};
        my $date      = $row->{date};
        my $info = $row->{info};
        my $dump = Data::Undumper::Undump($info, 1);

        $sth1->execute($date, $dump->{manager_id}, $dump->{borrowernumber});
        #print "SELECT * FROM accountlines WHERE date = $date AND manager_id = $dump->{manager_id} AND borrowernumber = $dump->{borrowernumber} AND register_id IS NULL AND credit_type_code = 'Pay'\n";
        $sth1_count->execute($date, $dump->{manager_id}, $dump->{borrowernumber});

        my $count = 0;
        if ( $sth1_count->fetchrow_hashref->{count} ) {
            while (my $pay_row = $sth1->fetchrow_hashref){
                unless ($count) {
                    $count++;
                    print "Found first matching payment\n";
                    $sth2->execute($timestamp);
                    my $counted = 0;
                    while (my $trans_row = $sth2->fetchrow_hashref) {
                        unless ($counted) {
                            $counted++;
                            if ( (0 - $trans_row->{amount}) == $pay_row->{amount} ) {
                                $sth3->execute($trans_row->{till}, $trans_row->{created}, $pay_row->{accountlines_id});
                                # Ensure offsets exist
                                for my $paid ( @{$dump->{accountlines_paid}} ) {
                                    $sth4->execute($pay_row->{accountlines_id}, $paid, '0', $timestamp);
                                }
                            } else {
                                print "Misfound transaction $trans_row->{amount} vs $pay_row->{amount}\n";
                            }
                        } else {
                            print "Second transaction found\n";
                        }
                    }
                } else {
                    print "Found another matching payment\n";           
                }
            }        
        } else {
            print "No matching accountlines found\n";
        }
    }

#    my $sth = $dbh->prepare( "SELECT date(created) AS created, amt, till, tcode, paymenttype, receiptid FROM cash_transactions" );
#    $sth->execture();
#    while ( my $row = $sth->fetchrow_hashref ) {
#        my $sth = $dbh->prepare("SELECT accountlines_id FROM accountlines WHERE debit_type_code = ? AND amount = ? ORDER BY date");
#
#    }

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Ches Accounts - description)\n";
}
