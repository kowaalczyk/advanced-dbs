-- cleanup
drop materialized view if exists top_authors, coauthor_graph;


-- create the coauthor graph
-- stats: 13088912 rows affected in 6 m 13 s 105 ms
create materialized view coauthor_graph as
    with coauthors as (
        select  a1.person_id as author1_id,
                a2.person_id as author2_id,
                a1.publication_key as publication_key
        from author a1
        left join author a2
        -- setting order on a join to represent each edge exactly once
        on a1.person_id < a2.person_id and a1.publication_key = a2.publication_key
        where a2.person_id is not null
    ),  publication_weight as (
        select  min(publication_key) as publication_key,
                (cast(1 as float8) / count(person_id)) as publ_weight
        from author
        group by publication_key
    ),  edge_weights as (
        select  min(author1_id) as author1_id,
                min(author2_id) as author2_id,
                count(coauthors.publication_key) as pair_count,
                sum(publ_weight) as pair_weight
        from coauthors
        left join publication_weight
        on coauthors.publication_key = publication_weight.publication_key
        group by author1_id, author2_id
    ) select * from edge_weights;

-- set indexes to speed up future queries
-- completed in 7 s 511 ms
create index coauthor_left_id on coauthor_graph (author1_id);
-- completed in 12 s 290 ms
create index coauthor_right_id on coauthor_graph (author2_id);

-- sanity check:
select * from coauthor_graph limit 10;


-- prepare query for accessing weights of a given author
-- stats: 2548563 rows affected in 54 s 634 ms
create materialized view top_authors as
    with left_author as (
        select  min(author1_id) as author_id,
                sum(pair_count) as author_count,
                sum(pair_weight) as author_weight
        from coauthor_graph
        group by author1_id
    ),  right_author as (
        select  min(author2_id) as author_id,
                sum(pair_count) as author_count,
                sum(pair_weight) as author_weight
        from coauthor_graph
        group by author2_id
    ),  author_union as (
        select * from left_author union all select * from right_author
    ),  author_weights as (
        select  min(author_id) as author_id,
                sum(author_count) as author_count,
                sum(author_weight) as author_weight
        from author_union
        group by author_id
    )   select  full_name,
                author_count,
                author_weight
        from author_weights
        left join person on author_weights.author_id = person.id
        order by (author_weight, author_count) desc;

-- sanity check
select * from top_authors limit 10;


-- calculate number of connected components

prepare get_author_component (int) as
with recursive search_graph(author_id, next_author_id, depth, path, cycle) as (
        select  g.author1_id,
                g.author2_id,
                1,
                array[row(g.author1_id)],
                false
        from coauthor_graph g
        where g.author1_id = $1 or g.author2_id = $1
        -- debug:
--         where g.author1_id = 4395 or g.author2_id = 4395  -- an adequately small example for debugging purposes
    union all
        (
            -- next_author can be either on left or right side of the relation,
            -- but we cannot use a nice union in recursive statements and have to use case instead
            select  case g.author1_id = sg.next_author_id when true then g.author1_id else g.author2_id end,
                    case g.author1_id = sg.next_author_id when true then g.author2_id else g.author1_id end,
                    sg.depth + 1,
                    path || case g.author1_id = sg.next_author_id when true
                        then row(g.author2_id)  -- the new node in our path is author2
                        else row(g.author1_id)  -- the new node in our path is author1
                    end,
                    case g.author1_id = sg.next_author_id when true
                        then row(g.author2_id)  -- the new node in our path is author2
                        else row(g.author1_id)  -- the new node in our path is author1
                    end = any(path) -- cycle = true if the following node was visited
            from coauthor_graph g, search_graph sg
            where (g.author1_id = sg.next_author_id or g.author2_id = sg.next_author_id) and not cycle
        )
),  connected_authors as (
    select author_id, next_author_id from search_graph
)   select author_id from connected_authors union select next_author_id from connected_authors;


-- for debugging
select count (publication_key) from author where person_id = 2;
select * from top_authors left join person on top_authors.full_name = person.full_name order by author_count asc limit 10;