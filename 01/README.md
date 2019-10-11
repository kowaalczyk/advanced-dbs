# Lab 01 - data model definition

Goal: design a data model that can efficiently store provided XML in postgres.


## Solution

I used the `stats.py` script to calculate some basic statistics / sanity checks for the entire XML file,
but I still mostly relied on DTD file describing data model for the XML.

I used vertabelo to model the data, in order to get automatically generated sql code, I only needed to extend it by
adding some enum types. Results of my work can be found in `data-model.pdf` and `init.sql`.


## Key design decisions

- publisher and school are stored in a separate relation, as they have much fewer distinct values than publications
  (enum would be even more efficient, but we may want to add new publishers or schools in the future)
- year is stored as small int - datetime takes more space, and using it to store just a year may be confusing
- it seems that author reference is only nullable for proceedings, but I think it's better not to enforce this constraint
  so that all relationships can be inferred by looking at the data model diagram
- another way to model the publication types would be to use inheritance, but this would make author queries
  unnecessarily complex
- the documentation says, that there is a way to infer person key from name and surname data,
  but I didn't get to testing it yet, so for now the solution is to have a simple, serial key
- key, url and crossref properties also seem to be related, but 
  [the postgres version used for lkdb does not support generated columns](https://stackoverflow.com/a/8250729)
  so we cannot save space that way - we have to store all of them
- `publnr` is not present in data - no way to infer type, assuming smallint
