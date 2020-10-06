INSERT INTO account_credit_types ( code, description, can_be_added_manually, is_system ) VALUES
('PAYMENT', 'Payment', 0, 1),
('WRITEOFF', 'Writeoff', 0, 1),
('FORGIVEN', 'Forgiven', 1, 1),
('CREDIT', 'Credit', 1, 1),
('LOST_FOUND', 'Lost item fee refund', 0, 1);
