-- get list of publications for author, with some of related content
-- example: https://dblp.uni-trier.de/pers/hd/d/Diks:Krzysztof
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

-- to get actual query results, execute the prepared statement:
execute get_author_publications ('Krzysztof Diks');

-- to get cost and time analysis of the query (example: queries/resutls/krzysztof_diks_analysis.yaml):
explain (analyze, costs, timing, format yaml) execute get_author_publications ('Krzysztof Diks');
