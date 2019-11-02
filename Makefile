all: parse-all load-all post-load

parse-all:
	tmux new-session -d -s "zbd-people" python3 04/xml_to_csv.py people data/dblp.xml
	tmux new-session -d -s "zbd-publications" python3 04/xml_to_csv.py publications data/dblp.xml
	tmux new-session -d -s "zbd-generic" python3 04/xml_to_csv.py generic data/dblp.xml

init:
	psql -h lkdb zbd < 04/init.sql

load-all: init
	./04/load.sh


post-load:
	psql -h lkdb zbd < 04/post-load.sql
