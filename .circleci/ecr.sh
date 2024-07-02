#!/bin/bash

ssm_parameter="$1"
container="database-replication:latest"

function fetch_ecr_url {
  json=$(aws ssm get-parameter \
  --name "${ssm_parameter}"    \
  --with-decryption            \
  --output json                \
  --color off)

  output=$(jq -r .Parameter.Value <<< "${json}")

  if [ -n "${output}" ]; then
    echo "${output}"
  else
    exit 1
  fi
}

ecr_url=$(fetch_ecr_url)

docker build -t "$container" .
docker tag "${container}" "${ecr_url}:latest"

aws ecr get-login-password | docker login --username AWS --password-stdin "${ecr_url}"

docker push "${ecr_url}:latest"
