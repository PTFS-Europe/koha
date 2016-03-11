INSERT INTO systempreferences (variable,value,options,explanation,type)
VALUES('CheckPrevIssue','hardno','hardyes|softyes|softno|hardno','By default, for every item issued, should we warn if the patron has borrowed that item in the past?','Choice');

ALTER TABLE categories
ADD (`checkprevissue` varchar(7) NOT NULL default 'inherit');

ALTER TABLE borrowers
ADD (`checkprevissue` varchar(7) NOT NULL default 'inherit');

ALTER TABLE deletedborrowers
ADD (`checkprevissue` varchar(7) NOT NULL default 'inherit');
