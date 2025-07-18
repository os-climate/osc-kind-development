#!/bin/bash

CLUSTER_NAME=${1:-kind-cluster} # Default cluster name if not provided
ACTION=${2:-create} # Action: create, delete, or status
CONFIG_FILE="kind-config.yaml" # Default Kind config file
CURRENT_DIR=$(pwd)
NAMESPACE="osclimate"
DAG_DIR="${CURRENT_DIR}/dags"

# Function to create a Kind cluster
create_cluster() {
    echo "Checking if DAG directory exists..."

    if [ ! -d "$DAG_DIR" ]; then
      echo "Error: $DAG_DIR directory not found. Please create it before running."
      exit 1
    fi

    # Detect OS
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    echo "Cluster current directory $DAG_DIR ."
    # Set permissions only on macOS/Linux
    if [[ "$OS" == "linux" || "$OS" == "darwin" ]]; then
      echo "Setting permissions on DAG directory $DAG_DIR (Linux/macOS)..."
      sudo chown -R 1000:0 "$DAG_DIR"
      sudo chmod -R g+rx "$DAG_DIR"
    else
      echo "Running on Windows - skipping permission change."
    fi
    echo "Creating Kind cluster: $CLUSTER_NAME..."
    cat <<EOF > $CONFIG_FILE
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
    # extraMounts:
    #   - hostPath: $DAG_DIR   # Replace with your local directory
    #     containerPath: /dags  # Path inside the Kind container
  - role: worker
    extraMounts:
      - hostPath: $DAG_DIR   # Replace with your local directory
        containerPath: /dags  # Path inside the Kind container
EOF

    kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"
    echo "Cluster $CLUSTER_NAME created successfully."
    echo "Setting resource limits for Kind containers..."
    docker update --cpus 4 --memory 12g --memory-swap 12g "$CLUSTER_NAME-control-plane"
    docker update --cpus 4 --memory 12g --memory-swap 12g "$CLUSTER_NAME-worker"
  
  echo "Cluster created and resource limits applied."
}

# Function to delete a Kind cluster
delete_cluster() {
    
    echo "Deleting Kind cluster: $CLUSTER_NAME..."

    # Delete PVCs
    for pvc in $(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
      echo "Deleting PVC $pvc in namespace $NAMESPACE"
      kubectl delete pvc $pvc -n $NAMESPACE
    done

  
    kubectl delete pv --grace-period=0 --force
    
    echo "PVC and PV cleanup complete."
    kind delete cluster --name "$CLUSTER_NAME"
        # kubectl config delete-context "$CLUSTER_NAME"

    echo "Cluster $CLUSTER_NAME deleted successfully."
}

fix_dag_permissions() {
  DAG_DIR="$1"
  echo "setup permissions on $DAG_DIR ..."

  OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"

  if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "darwin" ]]; then
    # Linux or macOS: fix permissions with chown and chmod
    echo "Detected OS: $OS_TYPE"
    if [ "$(id -u)" -ne 0 ]; then
      echo "You may need to run this script as root (or with sudo) to change ownership."
    fi
    sudo chown -R 1000:0 "$DAG_DIR"
    sudo chmod -R g+rx "$DAG_DIR"
    echo "Permissions updated for Linux/macOS."
  elif [[ "$OS_TYPE" == *"mingw"* || "$OS_TYPE" == *"cygwin"* || "$OS_TYPE" == *"msys"* ]]; then
    # Windows Git Bash / Cygwin / MSYS
    echo "Detected Windows environment ($OS_TYPE)."
    echo "Skipping chown/chmod as they are not applicable on Windows."
    echo "Ensure your Docker Desktop handles file sharing/mount permissions properly."
  else
    echo "Unknown OS type: $OS_TYPE. Please check permissions manually."
  fi
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
