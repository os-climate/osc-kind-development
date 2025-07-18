#!/bin/bash
set -e

IMAGES=(
  "osclimate/do"
  # "apache/airflow:2.9.3"
  "osclimate/minio:1.0"
  "quay.io/osclimate/hive-metastore:latest"
  "postgres:14"
  "postgres:13"
  "osclimate/trino:1.0"
  "redis:7"
)

# Temporary directory to store .tar files
TMP_DIR="docker_tar_files"
ZIP_FILE="docker_images_bundle.zip"

echo "Creating tarballs for local Docker images..."

mkdir -p "$TMP_DIR"

for image in "${IMAGES[@]}"; do
  echo "Saving image: $image"
  name=$(echo "$image" | tr '/:' '__')
  docker save -o "$TMP_DIR/${name}.tar" "$image"
done

echo "Zipping all tar files into $ZIP_FILE..."
rm -f "$ZIP_FILE"
zip -r "$ZIP_FILE" "$TMP_DIR"

echo " Done. Created $ZIP_FILE with saved images."
