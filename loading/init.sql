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
    publication_key varchar(80)  not null,
    bibtex text  null,
    aux text  null,
    constraint author_pk primary key (person_id,publication_key)
);

-- table: cite
create table cite (
    id serial  not null,
    str text  not null,
    publication_key varchar(80)  not null,
    label text  null,
    constraint cite_pk primary key (id)
);

-- table: crossref
create table crossref (
    id serial  not null,
    str text  not null,
    publication_key varchar(80)  not null,
    constraint crossref_pk primary key (id)
);

-- table: editor
create table editor (
    person_id int  not null,
    publication_key varchar(80)  not null,
    constraint editor_pk primary key (person_id,publication_key)
);

-- table: electronic_edition
create table electronic_edition (
    id serial  not null,
    url text  not null,
    publication_key varchar(80)  not null,
    is_archive boolean  not null default false,
    is_oa boolean  not null default false,
    constraint electronic_edition_pk primary key (id)
);

-- table: isbn
create table isbn (
    id serial  not null,
    isbn char(18)  not null,
    publication_key varchar(80)  not null,
    type isbn_type_enum  null,
    constraint isbn_pk primary key (id)
);

-- table: note
create table note (
    id serial  not null,
    note text  not null,
    label text  null,
    type note_type_enum  null,
    publication_key varchar(80)  not null,
    constraint note_pk primary key (id)
);

-- table: person
create table person (
    id serial  not null,
    full_name text  not null,
    orcid char(19)  null,
    constraint person_pk primary key (id)
);

-- table: publication
create table publication (
    key varchar(80)  not null,
    category publication_category_enum  not null,
    title text  null,
    year smallint  null,
    booktitle text  null,
    pages text  null,
    address text  null,
    journal text  null,
    volume smallint  null,
    number text  null,
    month month_enum  null,
    cdrom text  null,
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

-- table: publisher
create table publisher (
    id serial  not null,
    name text  not null,
    href text  null,
    constraint publisher_pk primary key (id)
);

-- table: school
create table school (
    id serial  not null,
    name text  not null,
    constraint school_pk primary key (id)
);

-- table: series
create table series (
    id serial  not null,
    name text  not null,
    href text  null,
    constraint series_pk primary key (id)
);

-- table: url
create table url (
    id serial  not null,
    url text  not null,
    type url_type_enum  null,
    publication_key varchar(80)  not null,
    constraint url_pk primary key (id)
);
