
-- custom data types:

CREATE TYPE publication_type_enum AS ENUM (
    'article',
    'inproceedings',
    'proceedings',
    'book',
    'incollection',
    'phdthesis',
    'mastersthesis',
    'www'
);

CREATE TYPE month_enum AS ENUM (
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
);


-- code generated using vertabelo (based on created data model):

-- Created by Vertabelo (http://vertabelo.com)
-- Last modification date: 2019-10-07 20:06:40.38

-- tables
-- Table: author
CREATE TABLE author (
    person_id int  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT author_pk PRIMARY KEY (person_id,publication_key)
);

-- Table: cite
CREATE TABLE cite (
    id serial  NOT NULL,
    str varchar(120)  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT cite_pk PRIMARY KEY (id)
);

-- Table: crossref
CREATE TABLE crossref (
    id serial  NOT NULL,
    str varchar(60)  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT crossref_pk PRIMARY KEY (id)
);

-- Table: editor
CREATE TABLE editor (
    person_id int  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT editor_pk PRIMARY KEY (person_id,publication_key)
);

-- Table: electronic_edition
CREATE TABLE electronic_edition (
    id serial  NOT NULL,
    url text  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT electronic_edition_pk PRIMARY KEY (id)
);

-- Table: person
CREATE TABLE person (
    id serial  NOT NULL,
    full_name varchar(120)  NOT NULL,
    CONSTRAINT person_pk PRIMARY KEY (id)
);

-- Table: publication
CREATE TABLE publication (
    key char(60)  NOT NULL,
    type publication_type_enum  NOT NULL,
    title varchar(120)  NOT NULL,
    year smallint  NOT NULL,
    booktitle varchar(120)  NULL,
    pages int4range  NULL,
    address varchar(60)  NULL,
    journal varchar(60)  NULL,
    volume smallint  NULL,
    number varchar(30)  NULL,
    month month_enum  NULL,
    url text  NULL,
    cdrom varchar(60)  NULL,
    note text  NULL,
    isbn varchar(60)  NULL,
    chapter smallint  NULL,
    publnr smallint  NULL,
    CONSTRAINT publication_pk PRIMARY KEY (key)
);

-- Table: publisher
CREATE TABLE publisher (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT publisher_pk PRIMARY KEY (id)
);

-- Table: school
CREATE TABLE school (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT school_pk PRIMARY KEY (id)
);

-- Table: series
CREATE TABLE series (
    id serial  NOT NULL,
    name varchar(120)  NOT NULL,
    href text  NULL,
    publication_key char(60)  NOT NULL,
    CONSTRAINT series_pk PRIMARY KEY (id)
);

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

-- Reference: publisher_publication (table: publisher)
ALTER TABLE publisher ADD CONSTRAINT publisher_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: school_publication (table: school)
ALTER TABLE school ADD CONSTRAINT school_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- Reference: series_publication (table: series)
ALTER TABLE series ADD CONSTRAINT series_publication
    FOREIGN KEY (publication_key)
    REFERENCES publication (key)
    NOT DEFERRABLE
    INITIALLY IMMEDIATE
;

-- End of file.
