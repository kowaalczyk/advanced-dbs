#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

data_dir="$1"
conninfo="$2"

tables_to_insert="author cite crossref editor electronic_edition isbn note person publication publisher school series url"

# shellcheck disable=SC2231
for csv in $data_dir/*.csv; do
  table_name="$(basename "$csv" .csv)"
  columns=$(head -n 1 "$csv" | tr '"' ' ' )
  echo "Processing $table_name ($columns)"
  if [[ $tables_to_insert =~ $table_name  ]]; then
    start=$(date +%s)
    psql -d "$conninfo" -c "\copy $table_name ($columns) from $csv with (format csv, header true)" | tee "loading/logs/$table_name.log"
    end=$(date +%s)
    echo "Table $table_name loaded in $((end-start))s"

  fi
  echo ""
done
