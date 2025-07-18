#!/usr/bin/env bash
set -euo pipefail

KIND_CLUSTER="osclimate-cluster"

echo "🔍 Listing all container images in Kind cluster '$KIND_CLUSTER'..."

for node in $(kind get nodes --name "$KIND_CLUSTER"); do
  echo -e "\n Images in node: $node"
  docker exec "$node" ctr -n k8s.io images list | awk 'NR==1 || /docker\.io|quay\.io|osclimate|localhost|library/' | column -t
done
