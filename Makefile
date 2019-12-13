conninfo := "postgres://postgres:postgres@localhost:5432"
conninfo_db := "postgres://postgres:postgres@localhost:5432/zbd"

db-up:
	docker run -d -p 5432:5432 postgres:9-alpine

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

parse-sample:
	python3 loading/xml_to_csv.py people data-sample/dblp-sample.xml 65519
	python3 loading/xml_to_csv.py publications data-sample/dblp-sample.xml 65519
	python3 loading/xml_to_csv.py generic data-sample/dblp-sample.xml 65519

init:
	psql -d $(conninfo_db) < loading/init.sql

load-all:
	./loading/format.sh data
	./loading/load.sh data $(conninfo_db)

load-sample:
	./loading/format.sh data-sample
	./loading/load.sh data-sample $(conninfo_db)

post-load:
	psql -d $(conninfo_db) < loading/post-load.sql

benchmark:
	python queries/benchmark.py $(conninfo_db) queries/results/authors_100_top_100_rand.csv
