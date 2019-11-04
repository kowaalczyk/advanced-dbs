conninfo := "postgres://postgres:postgres@localhost:5432/zbd"

db-up:
	docker run --name postgres -d -p 5432:5432 postgres:9-alpine

db-create:
	psql -d $(conninfo) -c "create database zbd"

db-down:
	docker stop postgres

db-logs:
	docker logs postgres

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

benchmark:
	python queries/benchmark.py $(conninfo) queries/results/authors_100_top_100_rand.csv
