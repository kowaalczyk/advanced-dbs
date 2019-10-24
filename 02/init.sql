-- updated dblp database initialization script

-- clear tables from previous iteration:

drop table if exists author, editor, person, electronic_edition, crossref, cite, series, note, url, isbn, school, publisher, publication;
drop type if exists publication_category_enum, month_enum, publication_type_enum, isbn_type_enum, url_type_enum, note_type_enum;

-- custom data types:

create type publication_category_enum as enum (
    'article',
    'inproceedings',
    'proceedings',
    'book',
    'incollection',
    'phdthesis',
    'mastersthesis',
    'www'
);

create type month_enum as enum (
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december'
);

create type publication_type_enum as enum (
    'habil',
    'withdrawn',
    'survey',
    'informal withdrawn',
    'noshow',
    'disambiguation',
    'data',
    'software',
    'encyclopedia',
    'edited',
    'group',
    'informal'
);

create type isbn_type_enum as enum (
    'usb', 'print', 'online', 'electronic'
);

create type url_type_enum as enum (
    'archive', 'deprecated'
);

create type note_type_enum as enum (
    'source', 'rating', 'uname', 'reviewid', 'disstype', 'affiliation', 'doi', 'isnot', 'isbn', 'award'
);


-- code generated using vertabelo (based on created data model):

-- Created by Vertabelo (http://vertabelo.com)
-- Last modification date: 2019-10-19 23:30:21.046

-- tables
-- Table: author
CREATE TABLE author (
    person_id int  NOT NULL,
    publication_key char(60)  NOT NULL,
    bibtex varchar(60)  NULL,
    aux varchar(20)  NULL,
    CONSTRAINT author_pk PRIMARY KEY (person_id,publication_key)
);

CREATE INDEX author_person_id on author (person_id ASC);

CREATE INDEX author_publication_key on author (publication_key ASC);

-- Table: cite
CREATE TABLE cite (
    id serial  NOT NULL,
    str varchar(120)  NOT NULL,
    publication_key char(60)  NOT NULL,
    label varchar(10)  NULL,
    CONSTRAINT cite_pk PRIMARY KEY (id)
);

CREATE INDEX cite_publication_key on cite (publication_key ASC);

-- Table: crossref
CREATE TABLE crossref (
    id serial  NOT NULL,
    str varchar(60)  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT crossref_pk PRIMARY KEY (id)
);

CREATE INDEX crossref_publication_key on crossref (publication_key ASC);

-- Table: editor
CREATE TABLE editor (
    person_id int  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT editor_pk PRIMARY KEY (person_id,publication_key)
);

CREATE INDEX editor_person_id on editor (person_id ASC);

CREATE INDEX editor_publication_key on editor (publication_key ASC);

-- Table: electronic_edition
CREATE TABLE electronic_edition (
    id serial  NOT NULL,
    url text  NOT NULL,
    publication_key char(60)  NOT NULL,
    is_archive boolean  NOT NULL DEFAULT false,
    is_oa boolean  NOT NULL DEFAULT false,
    CONSTRAINT electronic_edition_pk PRIMARY KEY (id)
);

CREATE INDEX electronic_edition_publication_key on electronic_edition (publication_key ASC);

-- Table: isbn
CREATE TABLE isbn (
    isbn char(18)  NOT NULL,
    publication_key char(60)  NOT NULL,
    type isbn_type_enum  NULL,
    CONSTRAINT isbn_pk PRIMARY KEY (isbn)
);

CREATE UNIQUE INDEX isbn_type_per_publication on isbn (type ASC,publication_key ASC);

-- Table: note
CREATE TABLE note (
    id serial  NOT NULL,
    note text  NOT NULL,
    label varchar(40)  NULL,
    type note_type_enum  NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT note_pk PRIMARY KEY (id)
);

CREATE INDEX note_publication_key on note (publication_key ASC);

-- Table: person
CREATE TABLE person (
    id serial  NOT NULL,
    full_name varchar(120)  NOT NULL,
    orcid char(19)  NULL,
    CONSTRAINT person_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX person_name on person (full_name ASC)
    WHERE orcid IS NULL;

CREATE UNIQUE INDEX person_name_orcid on person (full_name ASC,orcid ASC);

-- Table: publication
CREATE TABLE publication (
    key char(60)  NOT NULL,
    category publication_category_enum  NOT NULL,
    title varchar(512)  NOT NULL,
    year smallint  NOT NULL,
    booktitle varchar(512)  NULL,
    pages int4range  NULL,
    address varchar(60)  NULL,
    journal varchar(60)  NULL,
    volume smallint  NULL,
    number varchar(30)  NULL,
    month month_enum  NULL,
    cdrom varchar(60)  NULL,
    chapter smallint  NULL,
    publnr smallint  NULL,
    cdate date  NULL,
    mdate date  NULL,
    type publication_type_enum  NULL,
    title_bibtex varchar(512)  NULL,
    school_id int  NULL,
    publisher_id int  NULL,
    series_id int  NULL,
    CONSTRAINT publication_pk PRIMARY KEY (key)
);

CREATE INDEX publication_school_id on publication (school_id ASC);

CREATE INDEX publication_publisher_id on publication (publisher_id ASC);

CREATE INDEX publication_series_id on publication (series_id ASC);

-- Table: publisher
CREATE TABLE publisher (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    href varchar(60)  NULL,
    CONSTRAINT publisher_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX publisher_name on publisher (name ASC);

-- Table: school
CREATE TABLE school (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    CONSTRAINT school_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX school_name on school (name ASC);

-- Table: series
CREATE TABLE series (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    href text  NULL,
    CONSTRAINT series_pk PRIMARY KEY (id)
);

CREATE UNIQUE INDEX series_name on series (name ASC);

-- Table: url
CREATE TABLE url (
    id serial  NOT NULL,
    url text  NOT NULL,
    type url_type_enum  NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT url_pk PRIMARY KEY (id)
);

CREATE INDEX url_publication_key on url (publication_key ASC);

-- foreign keys
-- Reference: Author_Person (table: author)
ALTER TABLE author ADD CONSTRAINT Author_Person
    FOREIGN KEY (person_id)
    REFERENCES person (id)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: Author_Publication (table: author)
ALTER TABLE author ADD CONSTRAINT Author_Publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: Editor_Person (table: editor)
ALTER TABLE editor ADD CONSTRAINT Editor_Person
    FOREIGN KEY (person_id)
    REFERENCES person (id)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: Editor_Publication (table: editor)
ALTER TABLE editor ADD CONSTRAINT Editor_Publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: ElectronicEdition_Publication (table: electronic_edition)
ALTER TABLE electronic_edition ADD CONSTRAINT ElectronicEdition_Publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: cite_publication (table: cite)
ALTER TABLE cite ADD CONSTRAINT cite_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: crossref_publication (table: crossref)
ALTER TABLE crossref ADD CONSTRAINT crossref_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: isbn_publication (table: isbn)
ALTER TABLE isbn ADD CONSTRAINT isbn_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: note_publication (table: note)
ALTER TABLE note ADD CONSTRAINT note_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: publication_publisher (table: publication)
ALTER TABLE publication ADD CONSTRAINT publication_publisher
    FOREIGN KEY (publisher_id)
    REFERENCES publisher (id)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: publication_school (table: publication)
ALTER TABLE publication ADD CONSTRAINT publication_school
    FOREIGN KEY (school_id)
    REFERENCES school (id)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: publication_series (table: publication)
ALTER TABLE publication ADD CONSTRAINT publication_series
    FOREIGN KEY (series_id)
    REFERENCES series (id)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: url_publication (table: url)
ALTER TABLE url ADD CONSTRAINT url_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- End of file.
