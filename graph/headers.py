import os
from pathlib import Path
import csv
import sys


type_map = {
    "id": "id:ID({}-ID)",
    "key": "key:string",  # All IDs have to be same type, so publication key will be indexed later
    "person_id": "person_id:int",
    "school_id": "school_id:int",
    "publisher_id": "publisher_id:int",
    "series_id": "series_id:int",
    "is_oa": "is_oa:boolean",
    "is_archive": "is_archive:boolean",
    "year": "year:short",
    "pages": "pages:string",
    "volume": "volume:short",
    "chapter": "chapter:short",
    "publnr": "publnr:short",
    "cdate": "cdate:date",
    "mdate": "mdate:date",
}
# TODO: translate type_enums and month to points in graph


def create_headers_csv(file_path):
    path = Path(file_path)
    with path.open() as f:
        reader = csv.reader(f)
        colnames = next(reader)
    colnames_fmt = ", ".join(
        [type_map.get(colname, colname).format(path.name.replace(".csv", "")) for colname in colnames]
    )
    header_path = path.with_name(f"{path.name}.header")
    with header_path.open("w") as f:
        f.write(colnames_fmt)
        print(f"Created {header_path}")


def build_load_command(csvs):
    """
    Creates a bash script for data loading, intended to be executed from a location
    directly above neo4j import directory (datadir)
    """

    cmd = """
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
neo4j-admin import --id-type INTEGER \
    """
    for csv in csvs:
        entity_name = csv.replace('csv', '').capitalize()
        cmd += f'--nodes:{entity_name} "./import/{csv}.header,./import/{csv}" \\\n'
    return cmd


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [data_dir]")
        exit(2)
    else:
        data_dir = sys.argv[1]
        csvs = [f for f in os.listdir(data_dir) if f.endswith('csv')]
        for file in csvs:
            create_headers_csv(os.path.join(data_dir, file))
        load_cmd = build_load_command(csvs)
        with open(Path(data_dir) / 'load.sh', 'w') as f:
            f.write(load_cmd)
