-- indexes
create index author_person_id on author (person_id asc);
create index author_publication_key on author (publication_key asc);

create index cite_publication_key on cite (publication_key asc);

create index crossref_publication_key on crossref (publication_key asc);

create index editor_person_id on editor (person_id asc);
create index editor_publication_key on editor (publication_key asc);

create index electronic_edition_publication_key on electronic_edition (publication_key asc);

create unique index isbn_type_per_publication on isbn (type asc,publication_key asc);
create index isbn_isbn on isbn (isbn asc);

create index note_publication_key on note (publication_key asc);

create unique index person_name_orcid on person (full_name asc,orcid asc);
create unique index person_name on person (full_name asc)
    where orcid is null;

create index publication_school_id on publication (school_id asc);
create index publication_publisher_id on publication (publisher_id asc);
create index publication_series_id on publication (series_id asc);

create unique index publisher_name on publisher (name asc);

create unique index school_name on school (name asc);

create unique index series_name on series (name asc);

create index url_publication_key on url (publication_key asc);

-- foreign keys
-- reference: author_person (table: author)
alter table author add constraint author_person
    foreign key (person_id)
    references person (id)
    not deferrable
    initially immediate
;

-- reference: author_publication (table: author)
alter table author add constraint author_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: editor_person (table: editor)
alter table editor add constraint editor_person
    foreign key (person_id)
    references person (id)
    not deferrable
    initially immediate
;

-- reference: editor_publication (table: editor)
alter table editor add constraint editor_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: electronicedition_publication (table: electronic_edition)
alter table electronic_edition add constraint electronicedition_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: cite_publication (table: cite)
alter table cite add constraint cite_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: crossref_publication (table: crossref)
alter table crossref add constraint crossref_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: isbn_publication (table: isbn)
alter table isbn add constraint isbn_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: note_publication (table: note)
alter table note add constraint note_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;

-- reference: publication_publisher (table: publication)
alter table publication add constraint publication_publisher
    foreign key (publisher_id)
    references publisher (id)
    not deferrable
    initially immediate
;

-- reference: publication_school (table: publication)
alter table publication add constraint publication_school
    foreign key (school_id)
    references school (id)
    not deferrable
    initially immediate
;

-- reference: publication_series (table: publication)
alter table publication add constraint publication_series
    foreign key (series_id)
    references series (id)
    not deferrable
    initially immediate
;

-- reference: url_publication (table: url)
alter table url add constraint url_publication
    foreign key (publication_key)
    references publication (key)
    not deferrable
    initially immediate
;
