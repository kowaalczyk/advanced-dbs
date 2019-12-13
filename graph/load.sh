#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

data_dir="$1"

# copy all header files to neo4j import folder
echo "copying headers..."
cp "/minio/$data_dir/"*.csv.header "./import/"

for csv_file in "/minio/$data_dir/"*.csv; do
  # copy files without original headers to neo4j import folder
  csv_basename="$(basename "$csv_file")"
  echo "processing $csv_basename..."
  tail -n +2 "$csv_file" > "./import/$csv_basename"
done

echo "csvs and headers processed"

echo "loading..."

cp "/minio/$data_dir/load.sh" "./import/"
chmod +x "./import/load.sh"
./import/load.sh
#neo4j-admin import --id-type INTEGER \
#  --nodes:Author "./import/author.csv.header,./import/author.csv" \
#  --nodes:Cite "./import/cite.csv.header,./import/cite.csv" \
#  --nodes:Crossref "./import/crossref.csv.header,./import/crossref.csv" \
#  --nodes:Editor "./import/editor.csv.header,./import/editor.csv" \
#  --nodes:ElectronicEdition "./import/electronic_edition.csv.header,./import/electronic_edition.csv" \
#  --nodes:ISBN "./import/isbn.csv.header,./import/isbn.csv" \
#  --nodes:Note "./import/note.csv.header,./import/note.csv" \
#  --nodes:Person "./import/person.csv.header,./import/person.csv" \
#  --nodes:Publication "./import/publication.csv.header,./import/publication.csv" \
#  --nodes:Publisher "./import/publisher.csv.header,./import/publisher.csv" \
#  --nodes:School "./import/school.csv.header,./import/school.csv" \
#  --nodes:Series "./import/series.csv.header,./import/series.csv" \
#  --nodes:Url "./import/url.csv.header,./import/url.csv"

echo "csvs loaded"
