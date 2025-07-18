#!/usr/bin/env bash
set -euo pipefail

# Name of your kind cluster
KIND_CLUSTER_NAME="osclimate-cluster"
# Images to reload
IMAGES=(
  "osclimate/airflow:2.9.3"
  # "apache/airflow:2.9.3"
  "osclimate/trino:1.0"
  "osclimate/minio:1.0"
  "postgres:13"
  "postgres:14"
  "quay.io/osclimate/hive-metastore:latest"
  "redis:7"
  "redis:7.2-bookworm"

)


# Function to delete and reload image
reload_image() {
  local image=$1
  echo "Removing old $image from nodes (if present)..."

  for node in $(kind get nodes --name "$KIND_CLUSTER_NAME"); do
    docker exec "$node" crictl rmi "$image" || echo "$image not present on $node"
  done

  echo "🔄 Loading fresh $image into kind cluster '$KIND_CLUSTER_NAME'..."
  kind load docker-image "$image" --name "$KIND_CLUSTER_NAME"
}

# Loop through and reload each image
for image in "${IMAGES[@]}"; do
  reload_image "$image"
done

echo "Images reloaded into kind cluster '$KIND_CLUSTER_NAME'."