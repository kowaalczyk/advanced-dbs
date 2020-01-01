// ----------------------------------------------------------------------------------------------------------------
// 1. creating graph projections
// ----------------------------------------------------------------------------------------------------------------

// invalid projection I initially used, which does not capture any relationships
CALL algo.graph.load('authors_just_person', 'Person', 'authored');
// Query executed in 4796ms. Query type: READ_ONLY.

// this is also invalid as it would interpret all nodes (even non-person ones) as individual components
CALL algo.graph.load('authors_all', null, 'authored');
// Query executed in 2047ms. Query type: READ_ONLY.

// this seems good, but it would treat Person that is only an Editor (never authored anything) as an author component
CALL algo.graph.load('authors_person_publication', 'Person | Publication', 'authored')
// Query executed in 2302ms. Query type: READ_ONLY.

// this is the only correct graph
CALL algo.graph.load(
'authors_minimal',
'match (p:Person)-[:authored]->(:Publication) return id(p) as id
  union
  match (:Person)-[:authored]->(p:Publication) return id(p) as id',
'match (person:Person)-[:authored]->(pub:Publication)
  return id(person) as source, id(pub) as target',
{ graph: 'cypher' }
);
// Query executed in 145786ms. Query type: READ_ONLY.

// we clearly see this when comparing size of projections in terms of nodes and relationships:
CALL algo.graph.list() YIELD name, type, nodes, relationships;
/*
+------------------------------+--------+----------+---------------+
|             name             |  type  |  nodes   | relationships |
+------------------------------+--------+----------+---------------+
| "authors_person_publication" | "huge" |  9959098 |      16749193 |
| "authors_just_person"        | "huge" |  2760513 |             0 |
| "authors_minimal"            | "huge" |  9885754 |      16749193 |
| "authors_all"                | "huge" | 17804375 |      16749193 |
+------------------------------+--------+----------+---------------+
*/

// this fix already allows using algo.unionFind to examine distribution of connected component size etc:
CALL algo.unionFind(null, null, {
  graph: 'authors_person_publication',
  concurrency: 4,
  writeProperty: 'author_partition'
});
/*
Query executed in 67783ms. Query type: READ_WRITE.

+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+--------------------+--------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis |  nodes  | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 |  p100   | write | partitionProperty  |   writeProperty    |
+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+--------------------+--------------------+
|          2 |          1193 |       66324 |                  257 | 9959098 |         350727 |   350727 |  1 |  1 |   1 |   2 |   2 |   3 |   6 |   8 |  14 | 8840191 | true  | "author_partition" | "author_partition" |
+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+--------------------+--------------------+
*/

// we can see that the setCount is significantly lower when we exclude the 74 000 single-node sets of people who are just editors (not authors)
CALL algo.unionFind(null, null, {
  graph: 'authors_minimal',
  concurrency: 4,
  writeProperty: 'author_partition_minimal'
});
/*
Query executed in 422137ms. Query type: READ_WRITE.
+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+----------------------------+----------------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis |  nodes  | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 |  p100   | write |     partitionProperty      |       writeProperty        |
+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+----------------------------+----------------------------+
|          0 |           958 |      421425 |                  199 | 9885754 |         277383 |   277383 |  2 |  2 |   2 |   2 |   3 |   4 |   7 |   9 |  16 | 8840191 | true  | "author_partition_minimal" | "author_partition_minimal" |
+------------+---------------+-------------+----------------------+---------+----------------+----------+----+----+-----+-----+-----+-----+-----+-----+-----+---------+-------+----------------------------+----------------------------+
*/

// this approach has limitations:
// we cannot use weights and filtering based on strength of author-author connections
// because Publication nodes are also part of the graph we are working on

// remove unused projections from memmory:
CALL algo.graph.remove('authors_minimal');
CALL algo.graph.remove('authors_all');
CALL algo.graph.remove('authors_just_person');
CALL algo.graph.remove('authors_person_publication');


// ----------------------------------------------------------------------------------------------------------------
// 2. adding weights to nodes
// ----------------------------------------------------------------------------------------------------------------
// this is the tricky part - last time I tried, it took a long time to complete when executed from Postgres
// and did not complete at all on neo4j because of memory issues

// start by testing the expected time to get all results
MATCH (p:Person)-[:authored]-(pub:Publication) RETURN pub, count(p) LIMIT 10;
// Query executed in 90046ms. Query type: READ_ONLY.

// naive approach of creating coauthor relation does not work, as there is not enough memory:
MATCH (p1:Person)-[:authored]->(pub:Publication)<-[:authored]-(p2:Person)
WHERE id(p1) < id(p2)
MERGE (p1)-[r:is_coauthor]->(p2);
// After 20 minutes:
// Error occurred: There is not enough memory to perform the current task. Please try increasing 'dbms.memory.heap.max_size' in the neo4j configuration (normally in 'conf/neo4j.conf' or, if you you are using Neo4j Desktop, found through the user interface) or if you are running an embedded installation increase the heap by using '-Xmx' command line flag, and then restart the database. Details...

// instead, we'll try to add weights to publications and later do a cypher projection with added weights
MATCH (p:Person)-[:authored]->(pub:Publication)
WITH pub, count(p) AS author_count
SET pub += { n_authors: author_count } RETURN COUNT(*);
/*
Not enough memory on a laptop to perform this.

We continue the experiment on a 32GB, 8CPU server (just as during the previous attempts).
Fortunately, we're able to get the results:

+----------+
| COUNT(*) |
+----------+
| 7127342  |
+----------+

1 row available after 101120 ms, consumed after another 1 ms
Set 7127342 properties
*/

// check if author counts were assigned correctly:
match (p:Person)-[:authored]->(pub:Publication) with p.full_name as name, count(pub) as pub_count return name, pub_count order by pub_count desc limit 15;
/*
+------------------------------------+
| name                   | pub_count |
+------------------------------------+
| "H. Vincent Poor"      | 1785      |
| "Mohamed-Slim Alouini" | 1405      |
| "Philip S. Yu"         | 1334      |
| "Wei Wang"             | 1300      |
| "Wei Zhang"            | 1295      |
| "Lajos Hanzo"          | 1239      |
| "Wei Li"               | 1224      |
| "Wen Gao 0001"         | 1204      |
| "Victor C. M. Leung"   | 1143      |
| "Yu Zhang"             | 1134      |
| "Xin Wang"             | 1130      |
| "Lei Zhang"            | 1116      |
| "Hai Jin 0001"         | 1082      |
| "Lei Wang"             | 1081      |
| "Jun Wang"             | 1074      |
+------------------------------------+

15 rows available after 24903 ms, consumed after another 1 ms
*/

// check weights:
match (p:Person)-[:authored]->(pub:Publication)
with p.full_name as name, 1.0 / pub.n_authors as pub_weight
return name, sum(pub_weight) order by sum(pub_weight) desc limit 15;
/*
+----------------------------------------------+
| name                    | sum(pub_weight)    |
+----------------------------------------------+
| "H. Vincent Poor"       | 548.7363858363822  |
| "Ronald R. Yager"       | 440.67857142857076 |
| "Mohamed-Slim Alouini"  | 435.1904761904737  |
| "Witold Pedrycz"        | 428.2876984126954  |
| "Philip S. Yu"          | 388.040451215449   |
| "Lajos Hanzo"           | 368.5515623265595  |
| "Wei Wang"              | 366.3383068768131  |
| "Irith Pomeranz"        | 360.1833333333329  |
| "Wei Zhang"             | 355.8744583632726  |
| "T. D. Wilson 0001"     | 355.7166666666665  |
| "Wei Li"                | 345.42977942387415 |
| "Vladik Kreinovich"     | 340.14963924963774 |
| "Elisa Bertino"         | 339.4357614607602  |
| "Chin-Chen Chang 0001"  | 336.6333333333327  |
| "Georgios B. Giannakis" | 336.4226190476179  |
+----------------------------------------------+

15 rows available after 47759 ms, consumed after another 1 ms
*/
match (p:Publication) with p.title as title, 1.0 / p.n_authors as weight return title, weight order by weight limit 20;
/*
+-----------------------------------------------------------------------------------------------------------------------------------------------------------+
| title                                                                                                                             | weight                |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------+
| "The IceProd Framework: Distributed Data Processing for the IceCube Neutrino Observatory."                                        | 0.003484320557491289  |
| "The IceProd framework: Distributed data processing for the IceCube neutrino observatory."                                        | 0.003484320557491289  |
| "A promoter-level mammalian expression atlas."                                                                                    | 0.003787878787878788  |
| "The Sixth Visual Object Tracking VOT2018 Challenge Results."                                                                     | 0.0064516129032258064 |
| "The Visual Object Tracking VOT2016 Challenge Results."                                                                           | 0.007194244604316547  |
| "Length Sensing and Control in the Virgo Gravitational Wave Interferometer."                                                      | 0.008403361344537815  |
| "Machine Learning in High Energy Physics Community White Paper."                                                                  | 0.00847457627118644   |
| "An overview of the BlueGene/L Supercomputer."                                                                                    | 0.008695652173913044  |
| "Theano: A Python framework for fast computation of mathematical expressions."                                                    | 0.008928571428571428  |
| "The BioMart community portal: an innovative alternative to large, centralized data repositories."                                | 0.009523809523809525  |
| "VisDrone-DET2018: The Vision Meets Drone Object Detection in Image Challenge Results."                                           | 0.009523809523809525  |
| "The Visual Object Tracking VOT2017 Challenge Results."                                                                           | 0.009615384615384616  |
| "The Grid2003 Production Grid: Principles and Practice."                                                                          | 0.00980392156862745   |
| "Finding needles in haystacks: linking scientific names, reference specimens and molecular data for Fungi."                       | 0.009900990099009901  |
| "New vegetation type map of India prepared using satellite remote sensing: Comparison with global vegetation maps and utilities." | 0.010101010101010102  |
| "Integrative analysis of 111 reference human epigenomes Open."                                                                    | 0.010416666666666666  |
| "EVpedia: a community web portal for extracellular vesicles research."                                                            | 0.010526315789473684  |
| "TeraGrid: Analysis of Organization, System Architecture, and Middleware Enabling New Types of Applications."                     | 0.010638297872340425  |
| "Automatic identification of variables in epidemiological datasets using logic regression."                                       | 0.010869565217391304  |
| "Interoperation of world-wide production e-Science infrastructures."                                                              | 0.011764705882352941  |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------+
20 rows available after 11364 ms, consumed after another 1 ms
*/

// now for each pair of authors, we have to calculate weight of their connection as a sum of common publication weights
// this will be the most expensive operation so far, but hopefully the 32GB memory will be enough:
explain match (a1:Person)-[:authored]->(p1:Publication)
match (a2:Person)-[:authored]->(p2:Publication) where id(p1) = id(p2) and id(a2) > id(a1)
with sum(1.0 / p2.n_authors) as coauthor_weight
merge (a1)-[:is_coauthor { weight: coauthor_weight }]->(a2);
/*
+--------------------------------------------------------------------------+
| Plan      | Statement    | Version      | Planner | Runtime       | Time |
+--------------------------------------------------------------------------+
| "EXPLAIN" | "WRITE_ONLY" | "CYPHER 3.5" | "COST"  | "INTERPRETED" | 84   |
+--------------------------------------------------------------------------+


+------------------------------+-----------------+------------------------------------+--------------------------------------+
| Operator                     | Estimated Rows  | Identifiers                        | Other                                |
+------------------------------+-----------------+------------------------------------+--------------------------------------+
| +ProduceResults              |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +EmptyResult                 |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +Apply                       |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| |\                           +-----------------+------------------------------------+--------------------------------------+
| | +AntiConditionalApply      |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| | |\                         +-----------------+------------------------------------+--------------------------------------+
| | | +MergeCreateRelationship |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| | | |                        +-----------------+------------------------------------+--------------------------------------+
| | | +MergeCreateNode         |               1 | a1, a2, coauthor_weight            |                                      |
| | | |                        +-----------------+------------------------------------+--------------------------------------+
| | | +MergeCreateNode         |               1 | a1, coauthor_weight                |                                      |
| | | |                        +-----------------+------------------------------------+--------------------------------------+
| | | +Argument                |               1 | coauthor_weight                    |                                      |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +Optional                  |               1 | anon[197], a1, a2, coauthor_weight |                                      |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +ActiveRead                |               0 | anon[197], a1, a2, coauthor_weight |                                      |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +Filter                    |               0 | anon[197], a1, a2, coauthor_weight | `anon[197]`.weight = coauthor_weight |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +Expand(All)               |               0 | anon[197], a1, a2, coauthor_weight | (a1)-[anon[197]:is_coauthor]->(a2)   |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +AllNodesScan              |        17804375 | a1, coauthor_weight                |                                      |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +EagerAggregation            |               1 | coauthor_weight                    |                                      |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +Filter                      |         4726964 | a2, anon[18], p2, a1, p1, anon[66] | id(p1) = id(p2)                      |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +CartesianProduct            | 280535466151249 | a2, anon[18], p2, a1, p1, anon[66] |                                      |
| |\                           +-----------------+------------------------------------+--------------------------------------+
| | +Filter                    |        16749193 | anon[66], a2, p2                   | p2:Publication                       |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +Expand(All)               |        16749193 | anon[66], a2, p2                   | (a2)-[anon[66]:authored]->(p2)       |
| | |                          +-----------------+------------------------------------+--------------------------------------+
| | +NodeByLabelScan           |         2760513 | a2                                 | :Person                              |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +Filter                      |        16749193 | anon[18], a1, p1                   | p1:Publication                       |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +Expand(All)                 |        16749193 | anon[18], a1, p1                   | (a1)-[anon[18]:authored]->(p1)       |
| |                            +-----------------+------------------------------------+--------------------------------------+
| +NodeByLabelScan             |         2760513 | a1                                 | :Person                              |
+------------------------------+-----------------+------------------------------------+--------------------------------------+

CartesianProduct is way to big for query to complete, but we may try something else.
Reading on how to filted data using WITH statement, I noticed the part about it actually influencing the way data
is passed to the next query part. This gave me an idea: I could use WITH to change the naive query I initially created
by adding aggregation (in this case: sum) before the MERGE statement.

It turns out the improvement is quite big:
*/
explain match (a1:Person)-[:authored]->(p:Publication)<-[:authored]-(a2:Person)
where id(a2) > id(a1)
with a1, a2, sum(1.0 / p.n_authors) as coauthor_weight
merge (a1)-[:is_coauthor { weight: coauthor_weight }]->(a2);
/*
+------------------------------+----------------+------------------------------------+--------------------------------------+
| Operator                     | Estimated Rows | Identifiers                        | Other                                |
+------------------------------+----------------+------------------------------------+--------------------------------------+
| +ProduceResults              |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| |                            +----------------+------------------------------------+--------------------------------------+
| +EmptyResult                 |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| |                            +----------------+------------------------------------+--------------------------------------+
| +Apply                       |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| |\                           +----------------+------------------------------------+--------------------------------------+
| | +AntiConditionalApply      |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| | |\                         +----------------+------------------------------------+--------------------------------------+
| | | +MergeCreateRelationship |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +Argument                |           3419 | a1, a2, coauthor_weight            |                                      |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +AntiConditionalApply      |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| | |\                         +----------------+------------------------------------+--------------------------------------+
| | | +Optional                |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +ActiveRead              |              0 | anon[160], a1, a2, coauthor_weight |                                      |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +Filter                  |              0 | anon[160], a1, a2, coauthor_weight | `anon[160]`.weight = coauthor_weight |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +Expand(Into)            |              0 | anon[160], a1, a2, coauthor_weight | (a1)-[anon[160]:is_coauthor]->(a2)   |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +LockNodes               |           3419 | a1, a2, coauthor_weight            | a1, a2                               |
| | | |                        +----------------+------------------------------------+--------------------------------------+
| | | +Argument                |           3419 | a1, a2, coauthor_weight            |                                      |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +Optional                  |           3419 | anon[160], a1, a2, coauthor_weight |                                      |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +ActiveRead                |              0 | anon[160], a1, a2, coauthor_weight |                                      |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +Filter                    |              0 | anon[160], a1, a2, coauthor_weight | `anon[160]`.weight = coauthor_weight |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +Expand(Into)              |              0 | anon[160], a1, a2, coauthor_weight | (a1)-[anon[160]:is_coauthor]->(a2)   |
| | |                          +----------------+------------------------------------+--------------------------------------+
| | +Argument                  |           3419 | a1, a2, coauthor_weight            |                                      |
| |                            +----------------+------------------------------------+--------------------------------------+
| +EagerAggregation            |           3419 | a1, a2, coauthor_weight            | a1, a2                               |
| |                            +----------------+------------------------------------+--------------------------------------+
| +Filter                      |       11691275 | anon[18], anon[47], p, a1, a2      | a1:Person                            |
| |                            +----------------+------------------------------------+--------------------------------------+
| +Expand(All)                 |       38970918 | anon[18], anon[47], p, a1, a2      | (p)<-[anon[18]:authored]-(a1)        |
| |                            +----------------+------------------------------------+--------------------------------------+
| +Filter                      |       16749193 | anon[47], a2, p                    | p:Publication                        |
| |                            +----------------+------------------------------------+--------------------------------------+
| +Expand(All)                 |       16749193 | anon[47], a2, p                    | (a2)-[anon[47]:authored]->(p)        |
| |                            +----------------+------------------------------------+--------------------------------------+
| +NodeByLabelScan             |        2760513 | a2                                 | :Person                              |
+------------------------------+----------------+------------------------------------+--------------------------------------+

By far this still seems to be the best way of performing this query.
*/

// test execution speed:
match (a1:Person)-[:authored]->(p:Publication)<-[:authored]-(a2:Person)
where id(a2) > id(a1)
with a1, a2, sum(1.0 / p.n_authors) as coauthor_weight
return a1.full_name, a2.full_name, coauthor_weight order by coauthor_weight desc limit 20;
/*
+-------------------------------------------------------------------------+
| a1.full_name              | a2.full_name           | coauthor_weight    |
+-------------------------------------------------------------------------+
| "Irith Pomeranz"          | "Sudhakar M. Reddy"    | 184.31666666666666 |
| "Didier Dubois"           | "Henri Prade"          | 137.21386152547126 |
| "Tomoya Enokido"          | "Makoto Takizawa 0001" | 95.93333333333338  |
| "Shoji Hirano"            | "Shusaku Tsumoto"      | 89.26666666666664  |
| "Divyakant Agrawal"       | "Amr El Abbadi"        | 84.740873015873    |
| "Jelena V. Misic"         | "Vojislav B. Misic"    | 71.71666666666671  |
| "Patricia Melin"          | "Oscar Castillo 0001"  | 71.3595238095239   |
| "Nadia Magnenat-Thalmann" | "Daniel Thalmann"      | 70.48334443334448  |
| "Dennis Sylvester"        | "David T. Blaauw"      | 68.95303862803881  |
| "John McLeod"             | "Suzette McLeod"       | 64.58333333333333  |
| "Ioannis Pitas"           | "Anastasios Tefas"     | 62.252830097556384 |
| "Grzegorz Rozenberg"      | "Andrzej Ehrenfeucht"  | 62.2333333333334   |
| "Jiajun Bu"               | "Chun Chen 0001"       | 60.66904761904772  |
| "Makoto Ikeda"            | "Leonard Barolli"      | 59.06666666666662  |
| "Shojiro Nishio"          | "Takahiro Hara"        | 58.7944805194806   |
| "Yi Mu 0001"              | "Willy Susilo"         | 58.72142857142864  |
| "Zebo Peng"               | "Petru Eles"           | 55.22619047619053  |
| "M. Omair Ahmad"          | "M. N. S. Swamy"       | 53.800000000000104 |
| "Enrico Macii"            | "Massimo Poncino"      | 51.94026529026533  |
| "Eun-Jun Yoon"            | "Kee-Young Yoo"        | 51.09285714285715  |
+-------------------------------------------------------------------------+

20 rows available after 146216 ms, consumed after another 3 ms
*/

// test again, returning 4x more rows to make sure scaling is not an issue
// (because of sorting and ordering, query complexity should be the same regardless of output size limit)
match (a1:Person)-[:authored]->(p:Publication)<-[:authored]-(a2:Person)
where id(a2) > id(a1)
with a1, a2, sum(1.0 / p.n_authors) as coauthor_weight
return a1.full_name, a2.full_name, coauthor_weight order by coauthor_weight desc limit 80;
/*
+---------------------------------------------------------------------------------+
| a1.full_name              | a2.full_name                   | coauthor_weight    |
+---------------------------------------------------------------------------------+
| "Irith Pomeranz"          | "Sudhakar M. Reddy"            | 184.31666666666666 |
| "Didier Dubois"           | "Henri Prade"                  | 137.21386152547126 |
| "Tomoya Enokido"          | "Makoto Takizawa 0001"         | 95.93333333333338  |
| "Shoji Hirano"            | "Shusaku Tsumoto"              | 89.26666666666664  |
| "Divyakant Agrawal"       | "Amr El Abbadi"                | 84.740873015873    |
| "Jelena V. Misic"         | "Vojislav B. Misic"            | 71.71666666666671  |
| "Patricia Melin"          | "Oscar Castillo 0001"          | 71.3595238095239   |
| "Nadia Magnenat-Thalmann" | "Daniel Thalmann"              | 70.48334443334448  |
| "Dennis Sylvester"        | "David T. Blaauw"              | 68.95303862803881  |
| "John McLeod"             | "Suzette McLeod"               | 64.58333333333333  |
| "Ioannis Pitas"           | "Anastasios Tefas"             | 62.252830097556384 |
| "Grzegorz Rozenberg"      | "Andrzej Ehrenfeucht"          | 62.2333333333334   |
| "Jiajun Bu"               | "Chun Chen 0001"               | 60.66904761904772  |
| "Makoto Ikeda"            | "Leonard Barolli"              | 59.06666666666662  |
| "Shojiro Nishio"          | "Takahiro Hara"                | 58.7944805194806   |
| "Yi Mu 0001"              | "Willy Susilo"                 | 58.72142857142864  |
| "Zebo Peng"               | "Petru Eles"                   | 55.22619047619053  |
| "M. Omair Ahmad"          | "M. N. S. Swamy"               | 53.800000000000104 |
| "Enrico Macii"            | "Massimo Poncino"              | 51.94026529026533  |
| "Eun-Jun Yoon"            | "Kee-Young Yoo"                | 51.09285714285715  |
| "Miki Haseyama"           | "Takahiro Ogawa"               | 50.57777777777782  |
| "Guido Boella"            | "Leendert W. N. van der Torre" | 50.50952380952384  |
| "Saket Saurabh 0001"      | "Daniel Lokshtanov"            | 50.12067099567105  |
| "Irwin King"              | "Michael R. Lyu"               | 49.85238095238102  |
| "Thomas Rauber"           | "Gudula Rünger"                | 49.572619047619064 |
| "Nadia Nedjah"            | "Luiza de Macedo Mourelle"     | 49.53333333333339  |
| "Olivier Pivert"          | "Patrick Bosc"                 | 47.90952380952385  |
| "Jianzhong Li"            | "Hong Gao"                     | 47.39523809523816  |
| "Fumihito Arai"           | "Toshio Fukuda"                | 47.23015873015877  |
| "Symeon Chatzinotas"      | "Björn E. Ottersten"           | 47.123809523809555 |
| "Louise E. Moser"         | "P. M. Melliar-Smith"          | 46.9833333333334   |
| "Sheng Zhou"              | "Zhisheng Niu"                 | 46.490476190476265 |
| "Nora Cuppens-Boulahia"   | "Frédéric Cuppens"             | 46.34325396825398  |
| "Kiyoharu Aizawa"         | "Toshihiko Yamasaki"           | 46.271428571428615 |
| "Wen Gao 0001"            | "Debin Zhao"                   | 46.24761904761909  |
| "Richard T. Snodgrass"    | "Christian S. Jensen"          | 46.03409645909652  |
| "Masao Yanagisawa"        | "Nozomu Togawa"                | 45.828571428571465 |
| "Sakriani Sakti"          | "Satoshi Nakamura 0001"        | 44.260393772893835 |
| "Keikichi Hirose"         | "Nobuaki Minematsu"            | 43.99945697577279  |
| "Ralf Schlüter"           | "Hermann Ney"                  | 43.90461570593152  |
| "Xiaofei Liao"            | "Hai Jin 0001"                 | 43.811111111111124 |
| "Young-Koo Lee"           | "Sungyoung Lee"                | 43.652182539682556 |
| "Lie-Liang Yang"          | "Lajos Hanzo"                  | 43.48333333333337  |
| "Ciriaco Andrea D'Angelo" | "Giovanni Abramo"              | 43.41666666666667  |
| "Masayuki Inaba"          | "Kei Okada"                    | 43.2378750334633   |
| "Kiyohiro Shikano"        | "Hiroshi Saruwatari"           | 43.005158730158755 |
| "Chunhua Shen"            | "Anton van den Hengel"         | 42.75238095238097  |
| "Min Huang 0001"          | "Xingwei Wang 0001"            | 42.60476190476193  |
| "Agma J. M. Traina"       | "Caetano Traina Jr."           | 42.16230158730163  |
| "Edwin R. Hancock"        | "Richard C. Wilson 0001"       | 41.42500000000002  |
| "Anders Yeo"              | "Gregory Z. Gutin"             | 40.92063492063494  |
| "Shu-Ching Chen"          | "Mei-Ling Shyu"                | 40.78932178932181  |
| "David Taniar"            | "J. Wenny Rahayu"              | 40.64285714285714  |
| "Branka Vucetic"          | "Yonghui Li 0001"              | 40.402380952380945 |
| "Paola Flocchini"         | "Nicola Santoro"               | 40.31785714285715  |
| "Dacheng Tao"             | "Xuelong Li"                   | 40.21904761904764  |
| "K. J. Ray Liu"           | "Yan Chen 0007"                | 40.18333333333333  |
| "Achour Mostéfaoui"       | "Michel Raynal"                | 40.16666666666667  |
| "Frank Nielsen"           | "Richard Nock"                 | 40.1               |
| "Tetsuya Oda"             | "Leonard Barolli"              | 40.07857142857146  |
| "Leonard Barolli"         | "Fatos Xhafa"                  | 40.078571428571415 |
| "Muhammad Shafique 0001"  | "Jörg Henkel"                  | 39.63650793650795  |
| "Tetsuya Takiguchi"       | "Yasuo Ariki"                  | 39.53452380952381  |
| "Zhenan Sun"              | "Tieniu Tan"                   | 39.085964912280694 |
| "Petri Mähönen"           | "Janne Riihijärvi"             | 39.07983405483406  |
| "Charu C. Aggarwal"       | "Philip S. Yu"                 | 38.995670995671    |
| "Min-You Wu"              | "Wei Shu"                      | 38.83809523809525  |
| "Michitaka Hirose"        | "Tomohiro Tanikawa"            | 38.661904761904786 |
| "Hanne Riis Nielson"      | "Flemming Nielson"             | 38.61904761904762  |
| "Arjan Durresi"           | "Leonard Barolli"              | 38.542857142857144 |
| "Stan Z. Li"              | "Zhen Lei"                     | 38.361774628879886 |
| "Helmut Krcmar"           | "Jan Marco Leimeister"         | 38.00238095238097  |
| "Nikos Nikolaidis"        | "Ioannis Pitas"                | 37.88571428571429  |
| "Augusto Sarti"           | "Stefano Tubaro"               | 37.70519480519479  |
| "Shingo Mabu"             | "Kotaro Hirasawa"              | 37.67619047619048  |
| "Xin Zhang 0001"          | "Dacheng Yang"                 | 37.52857142857143  |
| "Jie Lu 0001"             | "Guangquan Zhang 0001"         | 37.466666666666654 |
| "Jian Li 0001"            | "Petre Stoica"                 | 37.416666666666664 |
| "Fuchun Sun"              | "Huaping Liu 0001"             | 37.1813492063492   |
| "Min Zhang 0006"          | "Shaoping Ma"                  | 37.01273448773449  |
+---------------------------------------------------------------------------------+

80 rows available after 123769 ms, consumed after another 9 ms
*/

// seems to be fine to run the entire merge query that will create coauthor links with appropriate weights
// we also add the count of common publications to the relationship, just in case
match (a1:Person)-[:authored]->(p:Publication)<-[:authored]-(a2:Person)
where id(a2) > id(a1)
with a1, a2, sum(1.0 / p.n_authors) as coauthor_weight, count(p) as coauthor_count
merge (a1)-[:is_coauthor { weight: coauthor_weight, common_publications: coauthor_count }]->(a2);
/*
+--------------------------------------------------------------------------+
| Plan      | Statement    | Version      | Planner | Runtime       | Time |
+--------------------------------------------------------------------------+
| "EXPLAIN" | "WRITE_ONLY" | "CYPHER 3.5" | "COST"  | "INTERPRETED" | 728  |
+--------------------------------------------------------------------------+


+------------------------------+----------------+----------------------------------------------------+--------------------------------------------------+
| Operator                     | Estimated Rows | Identifiers                                        | Other                                            |
+------------------------------+----------------+----------------------------------------------------+--------------------------------------------------+
| +ProduceResults              |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +EmptyResult                 |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +Apply                       |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| |\                           +----------------+----------------------------------------------------+--------------------------------------------------+
| | +AntiConditionalApply      |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | |\                         +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +MergeCreateRelationship |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +Argument                |           3419 | a1, a2, coauthor_count, coauthor_weight            |                                                  |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +AntiConditionalApply      |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | |\                         +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +Optional                |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +ActiveRead              |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +Filter                  |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 | `anon[188]`.common_publications = coauthor_count |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +Expand(Into)            |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 | (a1)-[anon[188]:is_coauthor]->(a2)               |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +LockNodes               |           3419 | a1, a2, coauthor_count, coauthor_weight            | a1, a2                                           |
| | | |                        +----------------+----------------------------------------------------+--------------------------------------------------+
| | | +Argument                |           3419 | a1, a2, coauthor_count, coauthor_weight            |                                                  |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +Optional                  |           3419 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +ActiveRead                |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 |                                                  |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +Filter                    |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 | `anon[188]`.common_publications = coauthor_count |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +Expand(Into)              |              0 | coauthor_weight, coauthor_count, anon[188], a1, a2 | (a1)-[anon[188]:is_coauthor]->(a2)               |
| | |                          +----------------+----------------------------------------------------+--------------------------------------------------+
| | +Argument                  |           3419 | a1, a2, coauthor_count, coauthor_weight            |                                                  |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +EagerAggregation            |           3419 | a1, a2, coauthor_count, coauthor_weight            | a1, a2                                           |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +Filter                      |       11691275 | anon[18], anon[47], p, a1, a2                      | a1:Person                                        |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +Expand(All)                 |       38970918 | anon[18], anon[47], p, a1, a2                      | (p)<-[anon[18]:authored]-(a1)                    |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +Filter                      |       16749193 | anon[47], a2, p                                    | p:Publication                                    |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +Expand(All)                 |       16749193 | anon[47], a2, p                                    | (a2)-[anon[47]:authored]->(p)                    |
| |                            +----------------+----------------------------------------------------+--------------------------------------------------+
| +NodeByLabelScan             |        2760513 | a2                                                 | :Person                                          |
+------------------------------+----------------+----------------------------------------------------+--------------------------------------------------+
*/

// running the entire query:
match (a1:Person)-[:authored]->(p:Publication)<-[:authored]-(a2:Person)
where id(a2) > id(a1)
with a1, a2, sum(1.0 / p.n_authors) as coauthor_weight, count(p) as coauthor_count
merge (a1)-[:is_coauthor { weight: coauthor_weight, common_publications: coauthor_count }]->(a2);
/*
Update 31-12-2019 19:55:
After 45 min the query still has not finished.

It's possible that in the previous statements LIMIT actually influenced the time to compute results.
Anyway, I'm sure it will manage to finish because the memory usage described in EXPLAIN query above is not big.

I'm going to leave the computation running until tomorrow afternoon to see if it in fact can be completed.

Also, important note: this is the *ONLY* query still runs slower on neo4j than on postgres
*/

// ----------------------------------------------------------------------------------------------------------------
// 3. running unionFind algorithm
// ----------------------------------------------------------------------------------------------------------------
// TODO: Use the new weights to run the algo.graph.load and unionFind, using queries below
// TODO: Or, given the long time necessary to perform coauthor join, use Traversal API to wrtite custom union-find instead

CALL algo.graph.load('authors_weighted', 'Person', 'is_coauthor')
CALL algo.unionFind.memrec(null, null, { graph: 'authors_weighted' }) yield requiredMemory;

// run algorithm without filtering - connected components should be the same as previously generated:
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition', weightProperty: 'weight' });
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_1', weightProperty: 'weight', threshold: 1.0 });
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_2', weightProperty: 'weight', threshold: 2.0 });
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_3', weightProperty: 'weight', threshold: 3.0 });
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_4', weightProperty: 'weight', threshold: 4.0 });
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_5', weightProperty: 'weight', threshold: 5.0 });



// ----------------------------------------------------------------------------------------------------------------
// 4. other experiments (now irrelevant)
// ----------------------------------------------------------------------------------------------------------------

CALL algo.graph.load(
  'authors_weighted',
  'match (p:Person)-[:authored]->(:Publication) return id(p) as id
    union
    match (:Person)-[:authored]->(p:Publication) return id(p) as id',
  'match (person:Person)-[:authored]->(pub:Publication)
    return id(person) as source, id(pub) as target, 1.0 / pub.n_authors as weight',
  { graph: 'cypher' }
);
/*
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| name               | graph    | direction  | undirected | sorted | nodes   | relationships | loadMillis | alreadyLoaded | nodeProperties | relationshipProperties | relationshipWeight |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| "authors_weighted" | "cypher" | "OUTGOING" | FALSE      | FALSE  | 9885754 | 16749193      | 161549     | FALSE         | NULL           | NULL                   | NULL               |
+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
1 row available after 161698 ms, consumed after another 12 ms
*/

call algo.unionFind.memrec(null, null, { graph: 'authors_weighted' }) yield requiredMemory;
/*
+-------------------------+
| requiredMemory          |
+-------------------------+
| "[368 MiB ... 457 MiB]" |
+-------------------------+

1 row available after 19 ms, consumed after another 0 ms
*/

// run algorithm without filtering - connected components should be the same as previously generated:
call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition', weightProperty: 'weight' });
/*
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis | nodes   | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 | p100    | write | partitionProperty    | writeProperty        |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 3          | 939           | 48153       | 249                  | 9885754 | 277383         | 277383   | 2  | 2  | 2   | 2   | 3   | 4   | 7   | 9   | 16  | 8840191 | TRUE  | "weighted_partition" | "weighted_partition" |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
1 row available after 49375 ms, consumed after another 0 ms
*/


call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_1', weightProperty: 'weight', threshold: 1.0 });
/*
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis | nodes   | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 | p100    | write | partitionProperty                | writeProperty                    |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 1          | 1155          | 50966       | 206                  | 9885754 | 277383         | 277383   | 2  | 2  | 2   | 2   | 3   | 4   | 7   | 9   | 16  | 8840191 | TRUE  | "weighted_partition_threshold_1" | "weighted_partition_threshold_1" |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

1 row available after 52353 ms, consumed after another 1 ms
*/

call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_2', weightProperty: 'weight', threshold: 2.0 });
/*
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis | nodes   | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 | p100    | write | partitionProperty                | writeProperty                    |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0          | 975           | 48791       | 210                  | 9885754 | 277383         | 277383   | 2  | 2  | 2   | 2   | 3   | 4   | 7   | 9   | 16  | 8840191 | TRUE  | "weighted_partition_threshold_2" | "weighted_partition_threshold_2" |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

1 row available after 49991 ms, consumed after another 0 ms

*/

call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_3', weightProperty: 'weight', threshold: 3.0 });
/*
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| loadMillis | computeMillis | writeMillis | postProcessingMillis | nodes   | communityCount | setCount | p1 | p5 | p10 | p25 | p50 | p75 | p90 | p95 | p99 | p100    | write | partitionProperty                | writeProperty                    |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 1          | 975           | 44303       | 275                  | 9885754 | 277383         | 277383   | 2  | 2  | 2   | 2   | 3   | 4   | 7   | 9   | 16  | 8840191 | TRUE  | "weighted_partition_threshold_3" | "weighted_partition_threshold_3" |
+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

1 row available after 45559 ms, consumed after another 0 ms
*/

call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_4', weightProperty: 'weight', threshold: 4.0 });
/*

*/

call algo.unionFind(null, null, { graph: 'authors_weighted', writeProperty: 'weighted_partition_threshold_5', weightProperty: 'weight', threshold: 5.0 });
/*

*/
