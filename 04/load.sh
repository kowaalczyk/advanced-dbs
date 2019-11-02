#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

data_dir="data"
psql_access="postgres://postgres:postgres@localhost:5432/zbd"

# shellcheck disable=SC2231
for csv in $data_dir/*.csv; do
  echo "Formatting $csv ($(du -h "$csv"))"
  sed -i '' 's/""//g' "$csv"
  sed -i '' -E 's/\.0+//g' "$csv"

  table_name="$(basename "$csv" .csv)"
  columns=$(head -n 1 "$csv" | tr '"' ' ' )
  echo "Uploading to $table_name ($columns)"

  start=$(date +%s)
  psql -d "$psql_access" -c "\copy $table_name ($columns) from $csv with (format csv, header true)"
  end=$(date +%s)
  echo "Table $table_name loaded in $((end-start))s"
  echo ""
done
