#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

data_dir="$1"

gnu_sed=$(sed --version 2>/dev/null || true)
if [[ -z "$gnu_sed" ]]; then
  echo "using osx sed"
else
  echo "using gnu sed"
fi

# shellcheck disable=SC2231
for csv in $data_dir/*.csv; do
  echo "Formatting $csv ($(du -h "$csv"))"
  start=$(date +%s)

  if [[ -z "$gnu_sed" ]]; then
    sed -i '' -E -e 's/""//g' -e 's/\.0+//g' "$csv"
  else
    sed -i -e 's/""//g' -e 's/\.0+//g' "$csv"
  fi
  end=$(date +%s)

  echo "File $csv formatted in $((end-start))s"
  echo ""
done
