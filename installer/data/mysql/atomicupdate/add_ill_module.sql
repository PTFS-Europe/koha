-- System preferences
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES ('ILLModule','0','If ON, enables the Inter-Library Loan module','','YesNo');
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES (
    'BookILLRequest',
    '0',
    'If ON, enables the requesting of books in the Inter-Library Loan module',
    '',
    'YesNo'
);
INSERT INTO systempreferences (variable,value,explanation,options,type)
VALUES (
    'JournalILLRequest',
    '0',
    'If ON, enables the requesting of journals in the Inter-Library Loan module',
    '',
    'YesNo'
);
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
INSERT INTO permissions (variable,value,explanation,options,type)
VALUES ('ILLEmailNotify',
    '0',
    'If ON, patrons receive an email notification of a placed request',
    '',
    'YesNo'
);
-- Userflags
INSERT INTO userflags (bit,flag,flagdesc,defaulton)
VALUES ('20','ill','Manage ILL requests','0');
-- Authorised Values
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLTYPE','ILLBOOK','Book request');
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLTYPE','ILLJOURNAL','Journal/Conference request');
UPDATE authorised_values set lib='Journal request' where authorised_value='ILLJOURNAL';
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLTYPE','ILLTHESIS','Thesis request');
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLTYPE','ILLOTHER','Other request');
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLTYPE','ILLCONFERENCE','Conference paper request');
INSERT INTO authorised_values (category,authorised_value,lib)
VALUES ('ILLSTATUS','NEW','New request');
-- Relations
CREATE TABLE illrequest (
    requestid int(11) unsigned NOT NULL auto_increment,
    requestnumber int(11) NOT NULL,
    borrowernumber int(11) NOT NULL,
    biblionumber int(11) default NULL,
    status varchar(50) NOT NULL default '',
    date_placed date default NULL,
    reply_date date default NULL,
    modified_date timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
    completed_date date default NULL,
    request_type varchar(50) NOT NULL default '',
    orig_branch varchar(50) default NULL,
    service_branch varchar(50) default NULL,
    title mediumtext,
    author_editor mediumtext,
    journal_title mediumtext,
    publisher mediumtext,
    issn mediumtext,
    year mediumtext,
    season mediumtext,
    month mediumtext,
    day mediumtext,
    volume mediumtext,
    part mediumtext,
    issue mediumtext,
    special_issue mediumtext,
    article_title mediumtext,
    author_names mediumtext,
    pages mediumtext,
    notes mediumtext,
    conference_title mediumtext,
    conference_author mediumtext,
    conference_venue mediumtext,
    conference_date mediumtext,
    isbn mediumtext,
    edition mediumtext,
    chapter_title mediumtext,
    composer mediumtext,
    ismn mediumtext,
    university mediumtext,
    dissertation mediumtext,
    scale mediumtext,
    identifier mediumtext,
    shelfmark mediumtext,
    local1 mediumtext,
    local2 mediumtext,
    local3 mediumtext,
    commercial_use set('y','n') NOT NULL default 'n',
    needed_by mediumtext,
    PRIMARY KEY  (requestid),
    UNIQUE KEY requestnumber (requestnumber),
    KEY borrowernumber (borrowernumber),
    KEY status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
-- Categories
ALTER TABLE categories ADD illlimit SMALLINT DEFAULT 0 AFTER hidelostitems;
