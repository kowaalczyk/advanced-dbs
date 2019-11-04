import sys
from datetime import datetime
import gc

# import psycopg2 as pg
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from tqdm import tqdm


authors_query = """
with top_autors as (
    select min(person.full_name) as full_name, count(a.publication_key) as count_publications from person
        left join author a on person.id = a.person_id
        group by person.id
        order by count(a.publication_key) desc
        limit 100
),  random_authors as (
    select min(person.full_name) as full_name, count(a.publication_key) as count_publications from person
        left join author a on person.id = a.person_id
        group by person.id
        order by random() desc
        limit 100
)   select * from top_autors union select * from random_authors;
"""

author_publications_prepare_query = """
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
"""

N_EXPERIMENTS = 10


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [postgres db conninfo] [path to csv with authors to search for (optional)]")
        exit(2)
    else:
        engine = create_engine(sys.argv[1])

        if len(sys.argv) == 3:
            print(f"Reading authors from to {sys.argv[2]}")
            authors = pd.read_csv(sys.argv[2], dtype={'full_name': str, 'count_publications': int})
        else:
            print(f"Connecting to {sys.argv[1]}")

            authors = pd.read_sql(authors_query, con=engine, columns=['full_name', 'count_publications'])

            authors_filename = 'queries/results/authors.csv'
            authors.to_csv(authors_filename)
            print(f"Authors saved to {authors_filename}")

    if not gc.isenabled():
        gc.enable()

    # noinspection PyUnboundLocalVariable
    with engine.connect() as conn:
        conn.execute(author_publications_prepare_query)

        # noinspection PyUnboundLocalVariable
        result_dfs = list()
        for experiment in range(N_EXPERIMENTS):
            print(f"Experiment {experiment+1} out of {N_EXPERIMENTS}")

            results = authors.copy()
            results['execution_time'] = None
            t = tqdm(authors['full_name'])
            for idx, author_name in enumerate(t):
                t.set_postfix_str(author_name)
                res = conn.execute(
                    "explain (analyze true, timing false, format json) execute get_author_publications (%s);", author_name
                )
                res_json = res.fetchone()[0][0]
                execution_time = res_json['Execution Time']
                results.loc[idx, 'execution_time'] = float(execution_time)
            t.close()

            results_summary = results[['execution_time']].agg(
                ['min', 'max', 'median', 'mean', 'std', 'sum', 'count']
            ).T.add_prefix('time_')
            results_summary['arg_max'] = [
                authors['full_name'].iloc[int(results['execution_time'].astype(np.float).idxmax(skipna=True))]
            ]
            results_summary['arg_min'] = [
                authors['full_name'].iloc[int(results['execution_time'].astype(np.float).idxmin(skipna=True))]
            ]

            experiment_name = datetime.now().replace(microsecond=0).isoformat()
            results_summary.index = [experiment_name]
            result_dfs.append(results_summary)
            print("")  # separator
            gc.collect()

    print("Saving results...")
    all_experiments_result_df = pd.concat(
        result_dfs, axis='index'
    )
    out_filename = f'queries/results/benchmark_{N_EXPERIMENTS}.csv'
    all_experiments_result_df.to_csv(out_filename, index=True, index_label='experiment_name')
    print(f"Results saved to: {out_filename}")
