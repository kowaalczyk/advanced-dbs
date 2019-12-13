import os
import sys
import subprocess


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} [files]")
        exit(2)
    else:
        import_dir = sys.argv[1]
        csvs = [f for f in os.listdir(import_dir) if f.endswith('csv')]
        """
        neo4j-admin import --id-type INTEGER \
  --nodes:Author "./import/author.csv.header,./import/author.csv" \
        """
        cmd = ["neo4j-admin", "import", "--id-type INTEGER"]
        for csv in csvs:
            entity_name = csv.replace('csv', '').capitalize()
            nodes_opt = f"--nodes:{entity_name} ./{import_dir}/{csv}.header,./{import_dir}/{csv}.csv"
            cmd.append(nodes_opt)
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        o, e = proc.communicate(timeout=60*15)
        os.write(1, o.decode('ascii'))
        os.write(2, e.decode('ascii'))
        exit(proc.returncode)

# backup version of loading, using cypher query lanquage:
#
# import sys
# import csv
# import os
# import time
# from collections import defaultdict
#
# from neo4j import GraphDatabase
#
#
# # we load csv files directly from minio
# load_file_template = """
# using periodic commit 500
# load csv with headers from 'http://minio:9000/{}' as row
# """
#
#
# type_dict = defaultdict(default_factory=lambda _: "string")
#
#
# def get_load_instruction(file_path):
#     load_instr = load_file_template.format(file_path)
#     table_name = os.path.splitext(os.path.basename(file_path))[0]
#     # query += f"merge (r:{table_name})"
#     with open(file_path) as f:
#         reader = csv.reader(f)
#         colnames = next(reader)
#     colnames_fmt = ", ".join(f"{colname}: row.{colname}" for colname in colnames)
#     load_instr += f"merge (i:{table_name} {{ {colnames_fmt} }})"
#     load_instr += "\nreturn count(i);"
#     return load_instr
#
#
# if __name__ == '__main__':
#     if len(sys.argv) < 2:
#         print(f"Usage: {sys.argv[0]} [nodes|edges] [files]")
#         exit(2)
#
#     elif sys.argv[1] == 'nodes':
#         uri = 'bolt://localhost:7687'
#         driver = GraphDatabase.driver(uri)
#
#         with driver.session() as session:
#             for csv_path in sys.argv[2:]:
#                 start = time.time()
#
#                 instr = get_load_instruction(csv_path)
#                 print(instr)
#                 loaded_rows = session.run(instr).single().value()
#
#                 end = time.time()
#                 print(f"{csv_path} loaded in {end-start:.2f}s")
#                 print(loaded_rows)
#                 print("")
#         exit(0)
#
#     elif sys.argv[1] == 'edges':
#         # TODO
#         print("Not implemented")
#         exit(1)
#
#     else:
#         print(f"Usage: {sys.argv[0]} [nodes|edges] [files]")
#         exit(2)
