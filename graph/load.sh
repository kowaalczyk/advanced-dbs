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
  echo "processing $csv_basename ($(du -h "$csv_file"))..."
  tail -n +2 "$csv_file" | sort -u > "./import/$csv_basename"
done

echo "csvs and headers processed"

echo "loading..."

cp "/minio/$data_dir/load.sh" "./import/"
chmod +x "./import/load.sh"
./import/load.sh

echo "csvs loaded"
