#!/bin/bash

CLUSTER_NAME=${1:-kind-cluster} # Default cluster name if not provided
ACTION=${2:-create} # Action: create, delete, or status
CONFIG_FILE="kind-config.yaml" # Default Kind config file
# CURRENT_DIR=$(pwd)
NAMESPACE="osclimate"


# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go one level up from scripts/ to reach the project root
CURRENT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to create a Kind cluster
create_cluster() {
    echo "Creating Kind cluster: $CLUSTER_NAME..."
    cat <<EOF > $CONFIG_FILE
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
    extraMounts:
      - hostPath: $CURRENT_DIR/dags   # Replace with your local directory
        containerPath: /dags  # Path inside the Kind container
      - hostPath: $CURRENT_DIR/logs
        containerPath: /logs
      - hostPath: $CURRENT_DIR/redis
        containerPath: /redis
  - role: worker
    extraMounts:
      - hostPath: $CURRENT_DIR/dags   # Replace with your local directory
        containerPath: /dags  # Path inside the Kind container
      - hostPath: $CURRENT_DIR/logs
        containerPath: /logs
      - hostPath: $CURRENT_DIR/redis
        containerPath: /redis

EOF

    kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"
    echo "Cluster $CLUSTER_NAME created successfully."
    echo "Setting resource limits for Kind containers..."
    docker update --cpus 4 --memory 12g --memory-swap 12g "$CLUSTER_NAME-control-plane"
    docker update --cpus 4 --memory 12g --memory-swap 12g "$CLUSTER_NAME-worker"
  
  echo "Cluster created and resource limits applied."
}

# Function to delete a Kind cluster
# delete_cluster() {
    
#     echo "Deleting Kind cluster: $CLUSTER_NAME..."

#     # Delete PVCs
#     for pvc in $(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
#       echo "Deleting PVC $pvc in namespace $NAMESPACE"
#       kubectl delete pvc $pvc -n $NAMESPACE
#     done

  
#     kubectl delete pv --grace-period=0 --force
    
#     echo "PVC and PV cleanup complete."
#     kind delete cluster --name "$CLUSTER_NAME"
#         # kubectl config delete-context "$CLUSTER_NAME"

#     echo "Cluster $CLUSTER_NAME deleted successfully."
# }

delete_cluster() {
    if [ -z "$CLUSTER_NAME" ] || [ -z "$NAMESPACE" ]; then
        echo "Error: CLUSTER_NAME or NAMESPACE is not set."
        return 1
    fi

    echo "Deleting Kind cluster: $CLUSTER_NAME..."
    echo "Cleaning up PVCs in namespace: $NAMESPACE"

    PVC_LIST=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

    if [ -z "$PVC_LIST" ]; then
        echo "No PVCs found in namespace $NAMESPACE."
    else
        for pvc in $PVC_LIST; do
            echo "Attempting to delete PVC: $pvc"
            kubectl delete pvc "$pvc" -n "$NAMESPACE" --timeout=10s

            # Check if PVC still exists (e.g. stuck in Terminating)
            if kubectl get pvc "$pvc" -n "$NAMESPACE" > /dev/null 2>&1; then
                echo "PVC $pvc is stuck. Removing finalizers..."
                kubectl patch pvc "$pvc" -n "$NAMESPACE" -p '{"metadata":{"finalizers":null}}' --type=merge
                kubectl delete pvc "$pvc" -n "$NAMESPACE" --grace-period=0 --force
            else
                echo "PVC $pvc deleted successfully."
            fi
        done
    fi

    echo "Deleting all PersistentVolumes..."
    kubectl delete pv --grace-period=0 --force

    echo "PVC and PV cleanup complete."

    echo "Deleting kind cluster: $CLUSTER_NAME"
    kind delete cluster --name "$CLUSTER_NAME"

    echo "Cluster $CLUSTER_NAME deleted successfully."
}


# Function to get cluster status
status_cluster() {
    echo "Fetching status for Kind cluster: $CLUSTER_NAME..."
    kubectl cluster-info --context "kind-$CLUSTER_NAME"
}
# Main logic
case "$ACTION" in
    create)
        create_cluster
        ;;
    delete)
        delete_cluster
        ;;
    status)
        status_cluster
        ;;
    *)
        echo "Usage: $0 <cluster-name> <create|delete|status>"
        exit 1
        ;;
esac