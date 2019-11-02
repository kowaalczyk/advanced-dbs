-- updated dblp database initialization script

-- clear tables from previous iteration:

drop table if exists author, editor, person, electronic_edition, crossref, cite, series, note, url, isbn, school, publisher, publication cascade;
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
-- created by vertabelo (http://vertabelo.com)
-- last modification date: 2019-11-01 21:59:04.869

-- tables
-- table: author
create table author (
    person_id int  not null,
    publication_key char(60)  not null,
    bibtex varchar(60)  null,
    aux varchar(20)  null,
    constraint author_pk primary key (person_id,publication_key)
);

-- create index author_person_id on author (person_id asc);
--
-- create index author_publication_key on author (publication_key asc);

-- table: cite
create table cite (
    id serial  not null,
    str varchar(120)  not null,
    publication_key char(60)  not null,
    label varchar(10)  null,
    constraint cite_pk primary key (id)
);

-- create index cite_publication_key on cite (publication_key asc);

-- table: crossref
create table crossref (
    id serial  not null,
    str varchar(60)  not null,
    publication_key char(60)  not null,
    constraint crossref_pk primary key (id)
);

-- create index crossref_publication_key on crossref (publication_key asc);

-- table: editor
create table editor (
    person_id int  not null,
    publication_key char(60)  not null,
    constraint editor_pk primary key (person_id,publication_key)
);

-- create index editor_person_id on editor (person_id asc);
--
-- create index editor_publication_key on editor (publication_key asc);

-- table: electronic_edition
create table electronic_edition (
    id serial  not null,
    url text  not null,
    publication_key char(60)  not null,
    is_archive boolean  not null default false,
    is_oa boolean  not null default false,
    constraint electronic_edition_pk primary key (id)
);

-- create index electronic_edition_publication_key on electronic_edition (publication_key asc);

-- table: isbn
create table isbn (
    id serial  not null,
    isbn char(18)  not null,
    publication_key char(60)  not null,
    type isbn_type_enum  null,
    constraint isbn_pk primary key (id)
);

-- create unique index isbn_type_per_publication on isbn (type asc,publication_key asc);
--
-- create index isbn_isbn on isbn (isbn asc);

-- table: note
create table note (
    id serial  not null,
    note text  not null,
    label varchar(40)  null,
    type note_type_enum  null,
    publication_key char(60)  not null,
    constraint note_pk primary key (id)
);

-- create index note_publication_key on note (publication_key asc);

-- table: person
create table person (
    id serial  not null,
    full_name varchar(120)  not null,
    orcid char(19)  null,
    constraint person_pk primary key (id)
);

-- create unique index person_name_orcid on person (full_name asc,orcid asc);
--
-- create unique index person_name on person (full_name asc)
--     where orcid is null;

-- table: publication
create table publication (
    key char(60)  not null,
    category publication_category_enum  not null,
    title text  not null,
    year smallint  null,
    booktitle text  null,
    pages int4range  null,
    address varchar(60)  null,
    journal varchar(60)  null,
    volume smallint  null,
    number varchar(30)  null,
    month month_enum  null,
    cdrom varchar(60)  null,
    chapter smallint  null,
    publnr smallint  null,
    cdate date  null,
    mdate date  null,
    type publication_type_enum  null,
    title_bibtex text  null,
    school_id int  null,
    publisher_id int  null,
    series_id int  null,
    constraint publication_pk primary key (key)
);

-- create index publication_school_id on publication (school_id asc);
--
-- create index publication_publisher_id on publication (publisher_id asc);
--
-- create index publication_series_id on publication (series_id asc);

-- table: publisher
create table publisher (
    id serial  not null,
    name varchar(120)  not null,
    href varchar(60)  null,
    constraint publisher_pk primary key (id)
);

-- create unique index publisher_name on publisher (name asc);

-- table: school
create table school (
    id serial  not null,
    name varchar(120)  not null,
    constraint school_pk primary key (id)
);

-- create unique index school_name on school (name asc);

-- table: series
create table series (
    id serial  not null,
    name varchar(120)  not null,
    href text  null,
    constraint series_pk primary key (id)
);

-- create unique index series_name on series (name asc);

-- table: url
create table url (
    id serial  not null,
    url text  not null,
    type url_type_enum  null,
    publication_key char(60)  not null,
    constraint url_pk primary key (id)
);

-- end of file.
