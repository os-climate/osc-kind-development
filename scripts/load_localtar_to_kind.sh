#!/bin/bash
set -e

# === CONFIGURATION ===
ZIP_FILE="${1:-docker_images_bundle.zip}"
TMP_DIR="docker_tar_files"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-osclimate-cluster}"  # Default to "kind"

# === CHECK CLUSTER ===
if ! kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
  echo "Error: Kind cluster '${KIND_CLUSTER_NAME}' not found."
  echo "Create it with: kind create cluster --name ${KIND_CLUSTER_NAME}"
  exit 1
fi

# === CLEANUP & UNZIP ===
echo " Unzipping $ZIP_FILE..."
rm -rf "$TMP_DIR"
unzip "$ZIP_FILE" -d .

# Detect if tar files are in TMP_DIR or nested inside TMP_DIR/TMP_DIR
TAR_PATH="$TMP_DIR"
if [ ! -f "$TAR_PATH"/*.tar ]; then
  # Maybe nested
  NESTED=$(find "$TMP_DIR" -type f -name "*.tar" | head -n 1)
  if [ -n "$NESTED" ]; then
    TAR_PATH=$(dirname "$NESTED")
  else
    echo "Error: No .tar files found after unzipping."
    exit 1
  fi
fi

# === LOAD IMAGES INTO KIND ===
echo "Loading Docker images into Kind cluster '${KIND_CLUSTER_NAME}'..."
for tar_file in "$TAR_PATH"/*.tar; do
  echo "Loading $(basename "$tar_file")"
  kind load image-archive "$tar_file" --name "$KIND_CLUSTER_NAME"
done

echo "All images loaded into Kind cluster '${KIND_CLUSTER_NAME}' successfully."
