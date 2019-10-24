import os

import psycopg2 as pg

from pydblp.models import Publication
from pydblp.translation import SECONDARY_DEPS_TAGNAMES


DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]
DB_HOST = os.environ.get("DB_HOST", "lkdb")
DBNAME = os.environ.get("DBNAME", "zbd")
# DB_PORT = "5432"

pg_connection_params = f"dbname={DBNAME} user={DB_USER} host={DB_HOST} password={DB_PASSWORD}"


def insert_publication_data(
        key: str,
        publ_cat: str,
        publication_attrs: dict,
        deps: list,
        data: list,
        secondary_deps: list
):
    # conn = pg.connect("dbname='postgres' user='postgres' host='localhost' port='5432' password='postgres'")
    conn = pg.connect(pg_connection_params)
    with open("/Users/kowal/Desktop/mimuw-projects/zbd/02/prepare.sql") as f:
        with conn.cursor() as cur:
            cur.execute(f.read())

            created_deps = dict()
            for dep in deps:
                cur.execute(*dep.insert_sql())
                result = cur.fetchone()
                if result is None:
                    cur.execute(*dep.select_sql())
                    result = cur.fetchone()
                created_deps[f'{dep.tablename__}_id'] = result
            publication_model = Publication(
                key=key,
                category=publ_cat,
                **publication_attrs,
                **created_deps
            )
            cur.execute(*publication_model.insert_sql())  # key is already known

            for person, relationship_type, relationship_attrs in secondary_deps:
                cur.execute(*person.insert_sql())
                person_id = cur.fetchone()
                if person_id is None:
                    cur.execute(*person.select_sql())
                    person_id = cur.fetchone()
                relationship = SECONDARY_DEPS_TAGNAMES[relationship_type](
                    person_id=person_id, publication_key=key, **relationship_attrs
                )
                cur.execute(*relationship.insert_sql())

            for data_item in data:
                cur.execute(*data_item.insert_sql())
    conn.commit()
    conn.close()
