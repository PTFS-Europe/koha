-- System preferences
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLModule','0','If ON, enables the Inter-Library Loan module','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('OpacILLRequests','0','If ON, allows patrons to view their ILL requests in the OPAC','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('UnmediatedILL','0','if ON, staff and members of the public will be able to place requests directly through the API, without staff moderation.','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('GenericILLModule','0','if ON, staff will have the option to place ILLs with partner libraries, instead of a central authority','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('GenericILLPartners','ILLLIBS','The borrower category to use to fetch ILL partner details.','','Free');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLEmailNotify','0','If ON, patrons receive an email notification of a placed request','','YesNo');

-- Userflags
INSERT INTO userflags (bit,flag,flagdesc,defaulton)
VALUES ('21','ill','The Interlibrary Loans Module','0');

-- Permissions
INSERT INTO permissions (module_bit,code,description)
VALUES ('21','place','Able to create ILL requests');
INSERT INTO permissions (module_bit,code,description)
VALUES ('21','manage','Able to create ILL requests');

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
    type varchar(200) NOT NULL,
    value text NOT NULL,
    FOREIGN KEY(req_id) REFERENCES ill_requests(id)
);
