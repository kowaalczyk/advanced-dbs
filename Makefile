init:
	psql -h lkdb zbd -f 02/init.sql

reinstall:
	pip install -e .

upload-full: reinstall
	python 02/load_data.py data/dblp.xml
