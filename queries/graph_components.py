import sys

import pandas as pd
from sqlalchemy import create_engine
from tqdm import tqdm

prepare_query = """
prepare get_author_component (int) as
with recursive search_graph(author_id, next_author_id, depth, path, cycle) as (
        select  g.author1_id,
                g.author2_id,
                1,
                array[row(g.author1_id)],
                false
        from coauthor_graph g
        where g.author1_id = $1 or g.author2_id = $1
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
"""


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [postgres db conninfo]")
        exit(2)
    else:
        engine = create_engine(sys.argv[1])

    # noinspection PyUnboundLocalVariable
    with engine.connect() as conn:
        print("querying list of authors...")
        # this is less than 200MB and can be stored in memory, to provide better progress feedback to the user
        # as well as easier caching of previously visited
        authors = pd.read_sql("select distinct person_id from author;", con=conn)
        authors['component'] = None
        authors.index = authors['person_id']

        print("preparing graph query...")
        conn.execute(prepare_query)

        current_component = 0
        for author_id in tqdm(authors['person_id'], desc="computing connected components"):
            if authors.loc[author_id, 'component'] is None:
                connected_authors = pd.read_sql("execute get_author_component (%s);", con=conn, params=(author_id,))
                authors.loc[list(connected_authors['author_id']), 'component'] = current_component
                current_component += 1
            else:
                pass  # author is part of previously calculated connected component

        results_df = authors.groupby('component')['person_id'].count()

        print("Saving results...")
        out_filename = f'queries/results/graph_components.csv'
        results_df.to_csv(out_filename, index=False)
        print(f"Results saved to: {out_filename}")
