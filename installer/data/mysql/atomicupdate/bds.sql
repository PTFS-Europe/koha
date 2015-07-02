
create table if not exists edifact_skeleton (
   biblionumber integer primary key,
   ordernumber integer not null,
   ean varchar(12),
   status varchar(10),
   lastactivity timestamp
);
