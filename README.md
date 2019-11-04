# Advanced DBs

Building an optimal relational database system for all data from [dblp.org](https://dblp.org).

Given its complexity, I feel like it can be a nice example of how to work with large datasets, in particular:

-   creating a relational schema for messy XML data
-   loading ~3GB dataset into SQL database
-   optimizing query performance
-   reliably benchmarking query execution times

The project is a result of assignments from Advanced Database Systems class, part of MSc in Computer Science
course at University of Warsaw. All of the code, except raw data from DBLP and its description are my own work.


## Working with the project

To reproduce / extend the project, you need to have the following programs installed:

-   python (3.6 or later)
-   python libraries: `pip install -r requirements.txt`
-   bash
-   psql (postgres client: `brew install libpq` or `apt install libpq`)
-   make (unless you want to run everything manually)
-   tmux (if you want to run scripts in the background)
-   postgres database (version 9.6) - I used [official postgres docker image](https://hub.docker.com/_/postgres), 
    if you use some other kind of installation you'll need to change authentication settings in the `Makefile`

On the high-level, this is how the workflow looks like:

1.  Adding raw data: dblp.xml is not included in this project, [get it here](https://dblp.org/xml/)
    and extract into `data` folder
2.  Data exploration: `python exploration/analyze.py` or `python exploration/stats.py` will parse
    the raw data to retrieve key tag and attribute statistics
3.  Loading the data:
    -    `make parse-all` will spawn 3 parallel tmux sessions, each parsing a subset of XML tags to CSV format
        compatible with our relational schema. **This process requires ~240GB of RAM and at least 8 CPU cores**,
        so I recommend running it on cloud (should take no longer than 4 hrs). Alternatively, you can run each
        parsing process sequentially, which will take 3x longer but use 3x less RAM, or even change the processing
        script (`loading/xml_to_csv.py`) to split processing into batches (that way the process will take days,
        but you'll be able to run it on your laptop). After the process finishes, you should have a CSV file
        for every table in the database (files will be locate in `data` folder)
    -    `make db-up` will spawn a docker container named `postgres`, running the database
    -    `make db-create` will create a database named `zbd`, in which all queries run
        (by default, you can change that in Makefile)
    -    `make init` will **clear the database** and set up necessary tables
    -    `make load-all` will load all CSV files into the database (takes <10min on my laptop)
    -    `make post-load` will add indexes and constraints (checking data integrity and improving query time)
4.  Running queries and benchmarks: `make benchmark` will benchmark auerying all relatedby author name
    as displayed on [this website](https://dblp.uni-trier.de/pers/hd/d/Diks:Krzysztof). 
    Running the benchmark on a fully populated database takes ~1h on a laptop

General project structure:

```
.
├── data  # raw XML data and parsed CSV files 
│   └── docs  # original documentation from dblp
├── exploration  # scripts for exploring xml file and theris results
├── loading  # scripts for loading data into database
│   └── logs  # logs from database upload
├── queries  # sql queries and scripts for benchmarking
│   └── results  # results of query benchmarks and analysis
└── utils  # utility scripts for fixing badly parsed pieces of data
```


## Assignments log

### Designing the database schema

I used the `stats.py` script to calculate some basic statistics / sanity checks for the entire XML file,
but I still mostly relied on DTD file describing data model for the XML. I used vertabelo to model the data, 
in order to get automatically generated sql code, I only needed to extend it by
adding some enum types. Results of my work can be found in `data-model.pdf` and `init.sql`.


### Original design decisions

-   publisher and school are stored in a separate relation, as they have much fewer distinct values than publications
    (enum would be even more efficient, but we may want to add new publishers or schools in the future)
-   year is stored as small int - datetime takes more space, and using it to store just a year may be confusing
-   it seems that author reference is only nullable for proceedings, but I think it's better not to enforce this constraint
    so that all relationships can be inferred by looking at the data model diagram
-   another way to model the publication types would be to use inheritance, but this would make author queries
    unnecessarily complex
-   the documentation says, that there is a way to infer person key from name and surname data,
    but I didn't get to testing it yet, so for now the solution is to have a simple, serial key
-   key, url and crossref properties also seem to be related, but 
    [the postgres version used for lkdb does not support generated columns](https://stackoverflow.com/a/8250729)
    so we cannot save space that way - we have to store all of them
-   `publnr` is not present in data - no way to infer type, assuming smallint


### Changes to schema enforced during data load

-   publication pages are stored as `text`, not `int4range`
-   primary key of `publication` has changed type `varchar(80)` from `char(60)` (larger and more efficient at the same time)
-   all `varchar` fields were changed to `text`, except `publciation.key`, `isbn.isbn` and `person.orcid`
-   `isbn` is not unique in the data, index changed not to enforce uniqueness
-   `publication.title` can be nullable


### Querying publications by author

The query is defined in `queries/author_publciations.sql`. As you can see in the benchmark results
(average query time: 1.86s), the performance is fine. Details of benchmark environment are defined
in `querues/benchmark.py`.

However, it seems that it could be greatly improved when we don't need to query coauthors of the publication.

The usual way of improving query performance, will involve experimenting with index types, creating materialized views
and caching, as well as tuning the database in general. Another way to improve speed, would be to denormalize the data 
and store all authors of a publication as a string, although this requires a bit more work when data is updated.
