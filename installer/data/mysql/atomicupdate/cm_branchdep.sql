alter table branches add column default_till integer(11) references cash_till( tillid );
alter table branches add constraint fk_default_till  FOREIGN KEY (default_till) references cash_till ( tillid );
