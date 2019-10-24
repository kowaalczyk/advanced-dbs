import typing as T
from datetime import datetime
from dataclasses import dataclass, asdict


class Model(object):
    def insert_sql(self):
        d = asdict(self)

        sql_query_values_placeholder = ", ".join(["%s" for _ in d])
        values_to_insert = tuple(
            v for k, v in d.items() if k != 'tablename__'
        )
        sql_query = f"execute insert_{self.tablename__}({sql_query_values_placeholder});"
        return sql_query, values_to_insert


class GetByName(object):
    def select_sql(self):
        sql_query = f"execute get_{self.tablename__}_id_by_name(%s);"
        return sql_query, (self.name,)


@dataclass
class School(Model, GetByName):
    name: str

    tablename__ = 'school'


@dataclass
class Publisher(Model, GetByName):
    name: str
    href: T.Optional[str] = None

    tablename__ = 'publisher'


@dataclass
class Series(Model, GetByName):
    name: str
    href: T.Optional[str] = None

    tablename__ = 'series'


@dataclass
class Publication(Model):
    key: str
    category: str  # enum
    title: str
    year: int
    booktitle: T.Optional[str] = None
    pages: T.Optional[T.Tuple[int, int]] = None
    address: T.Optional[str] = None
    journal: T.Optional[str] = None
    volume: T.Optional[int] = None
    number: T.Optional[str] = None
    month: T.Optional[str] = None  # enum
    cdrom: T.Optional[str] = None
    chapter: T.Optional[int] = None
    publnr: T.Optional[int] = None
    cdate: T.Optional[datetime] = None
    mdate: T.Optional[datetime] = None
    type__: T.Optional[str] = None
    title_bibtex: T.Optional[str] = None

    school_id: T.Optional[int] = None
    publisher_id: T.Optional[int] = None
    series_id: T.Optional[int] = None

    tablename__ = 'publication'


@dataclass
class Person(Model, GetByName):
    full_name: str
    orcid: T.Optional[str] = None

    tablename__ = 'person'

    def insert_sql(self):
        if self.orcid is None:
            sql_ret = f"execute insert_{self.tablename__}(%s);", (self.full_name,)
        else:
            sql_ret = f"execute insert_{self.tablename__}_with_orcid(%s, %s);", (self.full_name, self.orcid)
        return sql_ret

    def select_sql(self):
        if self.orcid is None:
            sql_ret = f"execute select_{self.tablename__}(%s);", (self.full_name,)
        else:
            sql_ret = f"execute select_{self.tablename__}_with_orcid(%s, %s);", (self.full_name, self.orcid)
        return sql_ret


@dataclass
class Author(Model):
    person_id: str
    publication_key: str
    bibtex: T.Optional[str] = None
    aux: T.Optional[str] = None

    tablename__ = 'author'


@dataclass
class Editor(Model):
    person_id: str
    publication_key: str

    tablename__ = 'editor'


@dataclass
class ElectronicEdition(Model):
    url: str
    publication_key: str
    is_archive: T.Optional[bool] = False
    is_oa: T.Optional[bool] = False

    tablename__ = 'electronic_edition'

    @classmethod
    def from_xml(cls, type__: str = "", **kwargs):
        is_archive = 'archive' in type__
        is_oa = 'oa' in type__
        return cls(is_oa=is_oa, is_archive=is_archive, **kwargs)


@dataclass
class CrossRef(Model):
    str__: str
    publication_key: str

    tablename__ = 'crossref'


@dataclass
class Cite(Model):
    str__: str
    publication_key: str
    label: T.Optional[str] = None

    tablename__ = 'cite'


@dataclass
class Note(Model):
    note: str
    label: T.Optional[str] = None
    type__: T.Optional[str] = None
    publication_key: str = None

    tablename__ = 'note'


@dataclass
class Url(Model):
    url: str
    type__: T.Optional[str] = None
    publication_key: str = None

    tablename__ = 'url'


@dataclass
class ISBN(Model):
    isbn: str
    publication_key: str
    type__: T.Optional[str] = None

    tablename__ = 'isbn'
