prepare insert_publication (
    char(60),
    publication_category_enum,
    varchar(512),
    smallint,
    varchar(512),
    int4range,
    varchar(60),
    varchar(60),
    smallint,
    varchar(30),
    month_enum,
    varchar(60),
    smallint,
    smallint,
    date,
    date,
    publication_type_enum,
    varchar(512),
    int,
    int,
    int
    )
    as insert into publication (key, category, title, year, booktitle, pages, address, journal, volume, number,
            month, cdrom, chapter, publnr, cdate, mdate, type, title_bibtex, school_id, publisher_id, series_id)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
       returning key as publication_key;

prepare insert_person (varchar(512))
    as insert into person (full_name)
        values ($1)
        on conflict do nothing
        returning id;

prepare select_person (varchar(512))
    as select id from person where full_name = $1 and orcid is null;

prepare insert_person_with_orcid (varchar(512), char(19))
    -- is there any nice way to use just one query for person insertion?
    as insert into person (full_name, orcid)
        values ($1, $2)
        on conflict do nothing
        returning id;

prepare select_person_with_orcid (varchar(512), char(19))
    as select id from person where full_name = $1 and orcid = $2;

prepare insert_author (int, char(60), varchar(60), varchar(20))
    as insert into author (person_id, publication_key, bibtex, aux)
       values ($1, $2, $3, $4)
       returning (person_id, publication_key);

prepare insert_editor (int, char(60))
    as insert into editor (person_id, publication_key)
       values ($1, $2)
       returning (person_id, publication_key);

prepare insert_publisher (varchar(512), char(60))
    as insert into publisher (name, href)
        values ($1, $2)
        on conflict do nothing
        returning id;

prepare get_publisher_id_by_name (varchar(512))
    as select id from publisher where name = $1;

prepare insert_school (varchar(512))
    as insert into school (name)
        values ($1)
        on conflict do nothing
        returning id;

prepare get_school_id_by_name (varchar(512))
    as select id from school where name = $1;

prepare insert_isbn (char(18), char(60), isbn_type_enum)
    as insert into isbn (isbn, publication_key, type)
       values ($1, $2, $3)
       returning isbn;

prepare insert_url (text, url_type_enum, char(60))
    as insert into url (url, type, publication_key)
       values ($1, $2, $3)
       returning id as url_id;

prepare insert_note (text, varchar(40), note_type_enum, char(40))
    as insert into note (note, label, type, publication_key)
       values ($1, $2, $3, $4)
       returning id as note_id;

prepare insert_series (varchar(512), text)
    as insert into series (name, href)
        values ($1, $2)
        on conflict do nothing
        returning id as series_id;

prepare get_series_id_by_name (varchar(512))
    as select id from series where name = $1;

prepare insert_cite (varchar(512), char(60), varchar(10))
    as insert into cite (str, publication_key, label)
       values ($1, $2, $3)
       returning id as cite_id;

prepare insert_crossref (varchar(512), char(60))
    as insert into crossref (str, publication_key)
       values ($1, $2)
       returning id as crossref_id;

prepare insert_electronic_edition (text, char(60), boolean, boolean)
    as insert into electronic_edition (url, publication_key, is_archive, is_oa)
       values ($1, $2, $3, $4)
       returning id as electronic_edition_id;

-- TODO: preparing one giant statement may be faster, but the arguments will be a complete mess
