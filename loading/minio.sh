#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

if [[ $(which mc) -ne 0 ]]; then
  echo "Minio client required:"
  echo "https://docs.min.io/docs/minio-client-complete-guide"
fi

mc config host add minio http://localhost:9000 AKIAIOSFODNN7EXAMPLE wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

data_dir="$1"
mc mb "minio/$data_dir" || true
mc cp --insecure "$data_dir"/*.csv "$data_dir"/*.csv.header "$data_dir/load.sh" "minio/$data_dir/"
