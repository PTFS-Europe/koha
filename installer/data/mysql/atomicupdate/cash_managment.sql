
create table cash_till (
	tillid integer(11) auto_increment not null,
	name varchar(20) not null,
	description varchar(100) not null,
	branch varchar(10),
	primary key (tillid),
        UNIQUE KEY name_branch (name,branch),
	foreign key (branch) references branches (branchcode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

create table cash_transcode (
	code varchar(10) not null,
        description varchar(100) not null default '',
	income_group varchar(10),
	taxrate varchar(10),
	visible_charge boolean not null default 1,
	primary key (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- alter table cash_transcode add column visible_charge boolean not null default 1;

create table cash_transaction (
	id serial not null,
	created datetime null,
	amt decimal(12,2) not null,
	till integer(11) not null,
	tcode varchar(10) not null,
        paymenttype varchar(10),
	primary key (id),
        foreign key (till) references cash_till (tillid),
	foreign key (tcode ) references cash_transcode( code )
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TRIGGER cash_transaction_insert BEFORE INSERT ON `cash_transaction`
FOR EACH ROW SET NEW.created = now();

INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES('CashManagement', '0', NULL , 'Use the cash management module to record money in and out', 'YesNo');

insert into userflags values ( 21, 'cashmanage', 'Access cash management', 0);
-- payment types should be linked to auth value

insert into authorised_values (category, authorised_value, lib)
   values( 'PaymentType', 'Cash', 'cash');

insert into authorised_values (category, authorised_value, lib)
   values( 'PaymentType', 'Card', 'Debit or Credit card');

insert into authorised_values (category, authorised_value, lib)
   values( 'PaymentType', 'Cheque', 'Cheque');

insert into authorised_values (category, authorised_value, lib)
   values( 'TaxRate', 'Standard Rate', 'VAT at standard rate');

insert into authorised_values (category, authorised_value, lib)
   values( 'TaxRate', 'None', 'Out of scope of VAT');

insert into authorised_values (category, authorised_value, lib)
   values( 'TaxRate', 'Exempt', 'Exempt');

insert into authorised_values (category, authorised_value, lib)
   values( 'TaxRate', 'Zero', 'Zero rated');

insert into authorised_values (category, authorised_value, lib)
   values( 'PaymentGroup', 'Default', 'Default');

ALTER TABLE accountlines MODIFY accounttype varchar(10);

alter table cash_till add column starting_float decimal(4,2) default 0.0;
