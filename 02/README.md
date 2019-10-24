# Lab 02 - data loading

Goal: implement a script loading all data to the database


## Database model changes

During my work on this assignment, I found it necessary to make following changes to my
data model from 1st assignment:
- I found that `isbn`, `url` and `note` elements can appear multiple times 
  for every publication, therefore I separated them into distinct tables
- I added missing XML attributes (I simply missed some of them in the 1st assignment,
  others I found unnecessary to take into account - that is until I saw other students have
  included them in their data models):
   - `type` for `publication`, `isbn`, `url` and `note`,
   - `orcid` for person and `aux` for `author
   - `bibtex` for `publication` and `author`
   - `label` for `note` and `cite`
   - `is_archive` and `is_oa` flags for `electronic_edition`, based on `type` XML attribute, defaulting to `false`
- One attribute that deserves special attention is `publtype`, which I included
  in `publication` table as `type`. To prevent confusing attribute names,
  I renamed what was previously `type` of `publication` to `category` (this attribute 
  tells us what kind of element (XML tag) the publication originally was in `dblp.xml`)
- I added indexes for all foreign keys as well as unique indexes for secondary keys
  for some columns (mostly those that have a `name` that will often be searched for),
  such as `school` or `person`
- I also reversed the relations from `publication` to `school`, `publisher` and `series`:
  originally both were `1..0`, now are `0..inf` so that one `publisher` or one `school`
  can be related to multiple `publications` in order to reduce data duplication
- While importning the data, I noticed I need to increase maximum size of publication title


## Solution

The current solution version is neither clean nor perfect, but it loads all of the data 
except a couple edge cases in less than 2hrs thanks to the use of asynchronous db calls.
The problems I still haven't fixed include:
- nested `inproceedings`, which may force me to change the parser
- `title` tags contaning nested formatting tags (`<i>`, `<b>`, etc.) - I have a simple fix for them,
  just haven't been able to get it done on time
- code structure can be improved a lot, I started writing SQL unnecessarily before I discovered
  how good the python wrapper is (I figured I shouldn't use the ORM for this task, 
  but now I'm starting to think `sqlalchemy` + `alembic` would help a lot here)
