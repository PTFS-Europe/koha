-- System preferences
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLModule','0','If ON, enables the Inter-Library Loan module','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('BookILLRequest', '0', 'If ON, enables the requesting of books in the Inter-Library Loan module', '', 'YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('JournalILLRequest', '0', 'If ON, enables the requesting of journals in the Inter-Library Loan module', '', 'YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ThesisILLRequest','0','If ON, enables the requesting of theses in the Inter-Library Loan module','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('OtherILLRequest','0','If ON, enables the requesting of generic items in the Inter-Library Loan module','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLRequestPrefix','ILLREQ-','Prefix for the ILL request ID','','free');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('OpacILLRequests','0','If ON, allows patrons to view their ILL requests in the OPAC','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLEmailNotify','0','If ON, patrons receive an email notification of a placed request','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLNewRequestStatus','NEW',' Default status for new ILL requests','NEW','Choice');

INSERT INTO systempreferences (variable, explanation, type)
VALUES ('ILLLocalField1', 'Custom field for ILL submission forms', 'free');
INSERT INTO systempreferences (variable, explanation, type)
VALUES ('ILLLocalField2', 'Custom field for ILL submission forms', 'free');
INSERT INTO systempreferences (variable, explanation, type)
VALUES ('ILLLocalField3', 'Custom field for ILL submission forms', 'free');
-- Permissions

-- Userflags
INSERT INTO userflags (bit,flag,flagdesc,defaulton)
VALUES ('20','ill','Manage ILL requests','0');

-- Borrower Categories
ALTER TABLE categories ADD illlimit VARCHAR(60) AFTER issuelimit;

-- ILL Requests

CREATE TABLE ill_requests (
    id serial PRIMARY KEY,
    borrowernumber integer REFERENCES borrowers (borrowernumber),
    biblionumber integer REFERENCES biblio (biblionumber),
    status varchar(50),
    placement_date date,
    reply_date date,
    ts timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completion_date date,
    reqtype varchar(30),
    branch varchar(50)
);

CREATE TABLE ill_request_attributes (
    req_id bigint(20) unsigned NOT NULL,
    type varchar(30) NOT NULL,
    value text NOT NULL,
    FOREIGN KEY(req_id) REFERENCES ill_requests(id)
);
