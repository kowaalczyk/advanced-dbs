#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

data_dir="data"

gnu_sed=$(sed --version 2>/dev/null || true)
if [[ -z "$gnu_sed" ]]; then
  echo "using osx sed"
else
  echo "using gnu sed"
fi

# shellcheck disable=SC2231
for csv in $data_dir/*.csv; do
  table_name="$(basename "$csv" .csv)"
  echo "Fixing $table_name"
  start=$(date +%s)

  if [[ $table_name == 'person' ]]; then
    if [[ -z "$gnu_sed" ]]; then
      sed -i '' -E -e "s/<author[a-zA-Z0-_9 \"-=_]*>//g" -e "s/<editor[a-zA-Z0-9 \"-=_]*>//g" "$csv"
    else
      sed -i -e "s/<author[a-zA-Z0-9 \"-=_]*>//g" -e "s/<editor[a-zA-Z0-9 \"-=_]*>//g" "$csv"
    fi
  else
    if [[ -z "$gnu_sed" ]]; then
      sed -i '' -E "s/<${table_name}[a-zA-Z0-9 \"-=_]*>//g" "$csv"
    else
      sed -i "s/<{$table_name}[a-zA-Z0-9 \"-=_]*>//g" "$csv"
    fi
  fi

  end=$(date +%s)
  echo "File $csv fixed in $((end-start))s"
  echo ""
done
