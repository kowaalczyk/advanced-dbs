import logging
import typing as T
import os

import psycopg2 as pg

from pydblp.models import Publication, Model, Person
from pydblp.translation import SECONDARY_DEPS_TAGNAMES


log = logging.getLogger(__name__)


DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
DB_HOST = os.environ.get("DB_HOST", "lkdb")
DBNAME = os.environ.get("DBNAME", "zbd")
# DB_PORT = "5432"

pg_connection_params = f"dbname={DBNAME} user={DB_USER} host={DB_HOST} password={DB_PASSWORD}"


def _execute_insert(
        cur,
        key: str,
        publ_cat: str,
        publication_attrs: T.Dict[str, T.Any],
        deps: T.List[Model],
        data: T.List[Model],
        secondary_deps: T.Tuple[Person, str, T.Dict[str, T.Any]]
):
    publication_attrs_from_deps = {
        f"{dep.tablename__}_{dep.returnkey__}": f"(select {dep.returnkey__} from inserted_{dep.tablename__}_{idx})"
        for idx, dep in enumerate(deps)
    }
    publication = Publication(
        key=key,
        category=publ_cat,
        **publication_attrs,
        **publication_attrs_from_deps
    )

    initial_items = [*deps, publication]
    for i in initial_items:
        isql, iargs = i.insert_sql()
        assert isql.count('%s') == len(iargs)
    sql_bits = [
        f"inserted_{item.tablename__}_{idx} as ({item.insert_sql()[0]})"
        for idx, item in enumerate(initial_items)
    ]
    sql_args = list()
    for item in initial_items:
        sql_args.extend(item.insert_sql()[1])

    for idx, item in enumerate(data):
        item_sql, item_args = item.insert_sql()
        assert item_sql.count('%s') == len(item_args)
        sql_bits.append(
            f"inserted_{item.tablename__}_{idx} as ({item_sql})"
        )
        sql_args.extend(item_args)

    people = list()
    people_args = list()
    relationships = list()
    relationships_args = list()
    for idx, (person, relationship_type, relationship_attrs) in enumerate(secondary_deps):
        person_sql, person_args = person.insert_sql()
        assert person_sql.count('%s') == len(person_args)

        people.append(
            f"inserted_person_{idx} as ({person_sql})"
        )
        people_args.extend(person_args)

        relationship = SECONDARY_DEPS_TAGNAMES[relationship_type](
            person_id=f"(select {person.returnkey__} from inserted_person_{idx})",
            publication_key=key,
            **relationship_attrs
        )
        relationship_sql, relationship_args = relationship.insert_sql()
        assert relationship_sql.count('%s') == len(relationship_args)

        relationships_args.extend(relationship_args)
        if idx == len(secondary_deps) - 1:
            # edge case: last item is inseted outside of with ... as ... block
            relationships.append(
                relationship_sql
            )
        else:
            relationships.append(
                f"inserted_relationship_{idx} as ({relationship_sql})"
            )

    sql_bits.extend(people)
    sql_args.extend(people_args)

    sql_bits.extend(relationships[:-1])  # last relationship insert edge case
    complete_query = "with {} \n {};".format(
        ', \n'.join(sql_bits), relationships[-1]
    )
    sql_args.extend(relationships_args)

    log.debug(complete_query)
    log.debug(sql_args)
    cur.execute(complete_query, tuple(sql_args))


def insert_publication_data(
        key: str,
        publ_cat: str,
        publication_attrs: T.Dict[str, T.Any],
        deps: T.List[Model],
        data: T.List[Model],
        secondary_deps: T.Tuple[Person, str, T.Dict[str, T.Any]]
):
    conn = pg.connect(pg_connection_params)
    with conn.cursor() as cur:
        _execute_insert(
            cur,
            key,
            publ_cat,
            publication_attrs,
            deps,
            data,
            secondary_deps
        )
    conn.commit()
    conn.close()


def batch_insert_data(publication_data: T.List[T.Tuple[T.Any]]) -> None:
    conn = pg.connect(pg_connection_params)
    with conn.cursor() as cur:
        for publication_data_item in publication_data:
            _execute_insert(
                cur,
                *publication_data_item
            )
    conn.commit()
    conn.close()
