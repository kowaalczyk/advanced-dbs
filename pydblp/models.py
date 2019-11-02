import typing as T
from datetime import datetime
from dataclasses import dataclass, asdict, field, fields


def _strip_trailing_underscore(s: str) -> str:
    if s.endswith("_"):
        return s[:-1]
    else:
        return s


@dataclass
class Model(object):
    tablename__ = None
    returnkey__ = 'id'
    foreignkeys__ = ()

    strattrs__: str = field(init=False, default="")
    placeholders__: str = field(init=False, default="")

    def __post_init__(self):
        assert self.tablename__ is not None
        assert type(self.returnkey__) == str or type(self.returnkey__) == tuple

        self.strattrs__ = "({})".format(", ".join([
            _strip_trailing_underscore(f.name) for f in fields(self)
            if not f.name.endswith("__")
        ]))
        self.placeholders__ = ", ".join([
            str(self._get_value_placeholder(f, v))
            for f, v in asdict(self).items()
            if not f.endswith("__")
        ])

    def _get_value_placeholder(self, attr: str, val: T.Any) -> str:
        if attr in self.foreignkeys__ and val is not None:
            return val  # foreign keys are pasted in-place
        else:
            return "%s"

    @property
    def values(self):
        return tuple(
            v for k, v in asdict(self).items()
            if not (k.endswith("__") or (k in self.foreignkeys__ and v is not None))
        )


@dataclass
class AlwaysInsertMixin(object):
    def insert_sql(self):
        sql_query = "insert into {} {} values ({}) returning {}".format(
            self.tablename__,
            self.strattrs__,
            self.placeholders__,
            self.returnkey__
        )
        return sql_query, self.values


@dataclass
class UpdateOrInsertMixin(object):
    uniqueattrs__: str = field(init=False, default="")

    def insert_sql(self):
        update_attrs = ", ".join([
            f"{f.name}=excluded.{f.name}"
            for f in fields(self) if not f.name.endswith("__")
        ])
        sql_query = "insert into {} {} values ({}) on conflict ({}) do update set {} returning {}".format(
            self.tablename__,
            self.strattrs__,
            self.placeholders__,
            self.uniqueattrs__,
            update_attrs,
            self.returnkey__
        )
        return sql_query, self.values


class GetByNameMixin(object):
    def select_sql(self):
        sql_query = f"select {self.returnkey__} from {self.tablename__} where name = %s"
        return sql_query, (self.name,)


@dataclass
class School(Model, UpdateOrInsertMixin, GetByNameMixin):
    name: str

    tablename__ = 'school'
    uniqueattrs__ = 'name'


@dataclass
class Publisher(Model, UpdateOrInsertMixin, GetByNameMixin):
    name: str
    href: T.Optional[str] = None

    tablename__ = 'publisher'
    uniqueattrs__ = 'name'


@dataclass
class Series(Model, UpdateOrInsertMixin, GetByNameMixin):
    name: str
    href: T.Optional[str] = None

    tablename__ = 'series'
    uniqueattrs__ = 'name'


@dataclass
class Publication(Model, AlwaysInsertMixin):
    key: str
    category: str  # enum
    title: str
    year: T.Optional[int] = None
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
    type_: T.Optional[str] = None
    title_bibtex: T.Optional[str] = None

    school_id: T.Optional[int] = None
    publisher_id: T.Optional[int] = None
    series_id: T.Optional[int] = None

    tablename__ = 'publication'
    returnkey__ = 'key'
    foreignkeys__ = ('school_id', 'publisher_id', 'series_id')


@dataclass
class Person(Model):
    """
    Because of 2 unique constraints:
    - (person name) when orcid is null
    - (person name, orcid)
    we need custom insertion and selection logic.
    """
    full_name: str
    orcid: T.Optional[str] = None

    tablename__ = 'person'

    def insert_sql(self):
        if self.orcid is None:
            sql_query = """
            insert into {} {}
            values ({})
            on conflict (full_name) where orcid is null
            do update set full_name=excluded.full_name
            returning {}
            """.format(
                self.tablename__,
                self.strattrs__,
                self.placeholders__,
                self.returnkey__
            )
        else:
            sql_query = """
            insert into {} {}
            values ({})
            on conflict (full_name, orcid)
            do update set full_name=excluded.full_name, orcid=excluded.orcid
            returning {}
            """.format(
                self.tablename__,
                self.strattrs__,
                self.placeholders__,
                self.returnkey__
            )
        return sql_query, self.values


@dataclass
class Author(Model, AlwaysInsertMixin):
    person_id: str
    publication_key: str
    bibtex: T.Optional[str] = None
    aux: T.Optional[str] = None

    tablename__ = 'author'
    returnkey__ = ('person_id', 'publication_key')
    foreignkeys__ = ('person_id',)  # 'publication_key' is input => always sanititzed


@dataclass
class Editor(Model, AlwaysInsertMixin):
    person_id: str
    publication_key: str

    tablename__ = 'editor'
    returnkey__ = ('person_id', 'publication_key')
    foreignkeys__ = ('person_id',)  # 'publication_key' is input => always sanititzed


@dataclass
class ElectronicEdition(Model, AlwaysInsertMixin):
    url: str
    publication_key: str
    is_archive: T.Optional[bool] = False
    is_oa: T.Optional[bool] = False

    tablename__ = 'electronic_edition'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed

    @classmethod
    def from_xml(cls, type_: str = "", **kwargs):
        is_archive = 'archive' in type_
        is_oa = 'oa' in type_
        return cls(is_oa=is_oa, is_archive=is_archive, **kwargs)


@dataclass
class CrossRef(Model, AlwaysInsertMixin):
    str_: str
    publication_key: str

    tablename__ = 'crossref'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed


@dataclass
class Cite(Model, AlwaysInsertMixin):
    str_: str
    publication_key: str
    label: T.Optional[str] = None

    tablename__ = 'cite'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed


@dataclass
class Note(Model, AlwaysInsertMixin):
    note: str
    label: T.Optional[str] = None
    type_: T.Optional[str] = None
    publication_key: str = None

    tablename__ = 'note'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed


@dataclass
class Url(Model, AlwaysInsertMixin):
    url: str
    type_: T.Optional[str] = None
    publication_key: str = None

    tablename__ = 'url'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed


@dataclass
class ISBN(Model, AlwaysInsertMixin):
    isbn: str
    publication_key: str
    type_: T.Optional[str] = None

    tablename__ = 'isbn'
    returnkey__ = 'isbn'
    foreignkeys__ = ()  # 'publication_key' is input => always sanititzed
