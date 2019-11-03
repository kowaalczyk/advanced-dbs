conninfo := "postgres://postgres:postgres@localhost:5432/zbd"
#export conninfo := "postgres://kk385830:x@lkdb/zbd"

all: parse-all init load-all post-load

parse-all:
	tmux new-session -d -s "zbd-people" python3 loading/xml_to_csv.py people data/dblp.xml
	tmux new-session -d -s "zbd-publications" python3 loading/xml_to_csv.py publications data/dblp.xml
	tmux new-session -d -s "zbd-generic" python3 loading/xml_to_csv.py generic data/dblp.xml

init:
	psql -d $(conninfo) < loading/init.sql

load-all:
	./loading/format.sh
	./loading/load.sh $(conninfo)

post-load:
	psql -d $(conninfo) < loading/post-load.sql
