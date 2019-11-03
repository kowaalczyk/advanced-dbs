select min(person.full_name), count(a.publication_key) from person
    left join author a on person.id = a.person_id
    group by person.id
    order by count(a.publication_key) desc
    limit 100;

prepare get_author_publications (text)
    as with author_keys as (
        select publication_key from person
            left join author on person.id = author.person_id
            where person.full_name = $1
    ),  author_publications as (
        select key, title, booktitle, journal, pages, year from author_keys
            left join publication on publication.key = author_keys.publication_key
    ),  author_publications_with_coauthors as (
        select * from author_publications
            left join author on author.publication_key = author_publications.key
    )   select full_name, key, title, booktitle, journal, pages, year from author_publications_with_coauthors
            left join person on person.id = author_publications_with_coauthors.person_id;

explain (analyze, costs, timing, format yaml) execute get_author_publications ('Jie Zhang');

execute get_author_publications ('Jie Zhang');

explain (analyze true, timing false, format json) execute get_author_publications ('Jie Zhang');