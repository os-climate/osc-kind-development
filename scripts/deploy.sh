#!/bin/bash



set -e

# Globals
NAMESPACE="osclimate"

KIND_CLUSTER="osclimate-cluster"

AIRFLOW_RELEASE="airflow"
# RELEASE_NAME="airflow"
VALUES_FILE="airflow-values.yaml"
AIRFLOW_VERSION="1.15.0"

TRINO_VALUES_FILE="trino-values.yaml"
TRINO_RELEASE="trino"
TRINO_VERSION="0.34.0"

MINIO_VALUES_FILE="minio-values.yaml"
MINIO_RELEASE="minio"
MINIO_VERSION="5.3.0"

AIRFLOW_IMAGE="osclimate/airflow"
AIRFLOW_TAG="2.9.3"

MINIO_IMAGE="osclimate/minio"
MINIO_TAG="1.0"

TRINO_IMAGE="osclimate/trino"
TRINO_TAG="1.0"


# DEPLOYMENT_DIR=$(pwd)

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go one level up from scripts/ to reach the project root
DEPLOYMENT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for required tools
check_dependencies() {
    echo "Checking dependencies..."
    for cmd in helm kubectl; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: $cmd is not installed. Please install it first."
            exit 1
        fi
    done
}

# Create Namespace
create_namespace() {
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE || echo "Namespace $NAMESPACE already exists."
    kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/service-account.yaml -n $NAMESPACE
    
}


deploy_postgres(){

  kubectl apply -f $DEPLOYMENT_DIR/deployment/postgres/deployment-postgress.yaml -n $NAMESPACE
  kubectl apply -f $DEPLOYMENT_DIR/deployment/postgres/service.yaml -n $NAMESPACE
#   kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/redis.yaml -n $NAMESPACE

}
# Deploy Airflow
deploy_airflow() {
    kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/deployment-airflow-pv.yaml
    kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/deployment-airflow-pvc.yaml -n $NAMESPACE

    kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/deployment-airflow.yaml -n $NAMESPACE 
    # kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/airflow-deployment.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/airflow-service.yaml -n $NAMESPACE 
    # kubectl apply -f $DEPLOYMENT_DIR/deployment/airflow/worker.yaml -n $NAMESPACE 
    

    # Deploy Airflow (replace with your YAML deployment file)
    echo "Deploying Airflow..."

    # Wait for at least one Airflow pod to exist
    echo "Waiting for Airflow pod to appear in namespace $NAMESPACE..."

    PORT=8080

    echo "Checking for running Airflow pod..."
    AIRFLOW_POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=airflow -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$AIRFLOW_POD_NAME" ]; then
      echo "No Airflow pod found. Exiting."
      exit 1
    fi

    echo "Waiting for pod $AIRFLOW_POD_NAME to be ready..."
    while [[ $(kubectl get pod $AIRFLOW_POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}') != "Running" ]]; do
      echo "Pod $AIRFLOW_POD_NAME is not ready yet. Retrying..."
      sleep 5
    done

    echo "Starting port-forwarding for pod $AIRFLOW_POD_NAME..."
    nohup kubectl port-forward $AIRFLOW_POD_NAME $PORT:$PORT -n $NAMESPACE > port-forward-airflow.log 2>&1 &

    echo "Port-forwarding started. Access Airflow at http://localhost:$PORT"

    echo "Coping dags to airflow pod $AIRFLOW_POD_NAME..."
    #kubectl cp $DEPLOYMENT_DIR/dags $NAMESPACE/$AIRFLOW_POD_NAME:/opt/airflow/

}


# Deploy trino
deploy_trino() {
    echo "Deploying Trino ..."

    kubectl apply -f $DEPLOYMENT_DIR/deployment/trino/configmap.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/trino/deployment.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/trino/service.yaml -n $NAMESPACE 
    
    # Wait for at least one Airflow pod to exist
    echo "Waiting for Trino pod to appear in namespace $NAMESPACE..."

    TRINO_PORT=8081

    echo "Checking for running trino pod..."
    TRINO_POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=trino -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$TRINO_POD_NAME" ]; then
      echo "No trino pod found. Exiting."
      exit 1
    fi

    echo "Waiting for pod $TRINO_POD_NAME to be ready..."
    while [[ $(kubectl get pod $TRINO_POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}') != "Running" ]]; do
      echo "Pod $TRINO_POD_NAME is not ready yet. Retrying..."
      sleep 5
    done

    echo "Starting port-forwarding for pod $TRINO_POD_NAME..."
    nohup kubectl port-forward $TRINO_POD_NAME $TRINO_PORT:$TRINO_PORT -n $NAMESPACE > port-forward-trino.log 2>&1 &

    echo "Port-forwarding started. Access Trino at http://localhost:$TRINO_PORT"
    
}
deploy_hive_metastore(){
    echo "Deploying Hive metastore ..."
    kubectl apply -f $DEPLOYMENT_DIR/deployment/hive-metastore/secret.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/hive-metastore/deployment-postgress.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/hive-metastore/service-postgres.yaml -n $NAMESPACE 

    kubectl apply -f $DEPLOYMENT_DIR/deployment/hive-metastore/deployment.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/hive-metastore/service.yaml -n $NAMESPACE 

}

deploy_minio() {
   
    echo "Deploying Minio..."

    kubectl apply -f $DEPLOYMENT_DIR/deployment/minio/deployment.yaml -n $NAMESPACE 
    kubectl apply -f $DEPLOYMENT_DIR/deployment/minio/service.yaml -n $NAMESPACE 
    
    # Wait for at least one Airflow pod to exist
    echo "Waiting for minio pod to appear in namespace $NAMESPACE..."

    MINIO_PORT=9001
    MINIO_PORT_FWD=9005

    echo "Checking for running minio pod..."
    MINIO_POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=minio -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$MINIO_POD_NAME" ]; then
      echo "No minio pod found. Exiting."
      exit 1
    fi

    echo "Waiting for pod $MINIO_POD_NAME to be ready..."
    while [[ $(kubectl get pod $MINIO_POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}') != "Running" ]]; do
      echo "Pod $MINIO_POD_NAME is not ready yet. Retrying..."
      sleep 5
    done

    echo "Starting port-forwarding for pod $MINIO_POD_NAME..."
    nohup kubectl port-forward $MINIO_POD_NAME $MINIO_PORT_FWD:$MINIO_PORT -n $NAMESPACE > port-forward-minio.log 2>&1 &

    echo "Port-forwarding started. Access minio at http://localhost:$MINIO_PORT_FWD"


}
# Verify Deployment
verify_deployment() {
    echo "Verifying  deployment..."
    kubectl get pods -n $NAMESPACE
    kubectl get svc -n $NAMESPACE
}


# 
load_images(){
    kind load docker-image $AIRFLOW_IMAGE:$AIRFLOW_TAG -n $KIND_CLUSTER 
    kind load docker-image $TRINO_IMAGE:$TRINO_TAG -n $KIND_CLUSTER
    kind load docker-image $MINIO_IMAGE:$MINIO_TAG -n $KIND_CLUSTER 

}
load_airflow_image(){
    kind load docker-image $AIRFLOW_IMAGE:$AIRFLOW_TAG -n $KIND_CLUSTER

}
load_trino_image(){
    kind load docker-image $TRINO_IMAGE:$TRINO_TAG -n $KIND_CLUSTER

}
load_minio_image(){
    kind load docker-image $MINIO_IMAGE:$MINIO_TAG -n $KIND_CLUSTER

}

# 
create_pvc(){
    kubectl apply -f airflow-local-dags-folder-pv.yaml
    kubectl apply -f airflow-local-dags-folder-pvc.yaml -n $NAMESPACE
    kubectl apply -f airflow-local-logs-folder-pv.yaml 
    kubectl apply -f airflow-local-logs-folder-pvc.yaml -n $NAMESPACE
}

port_forward(){

  kubectl port-forward svc/airflow-webserver 8080:8080 -n osclimate & \
  kubectl port-forward svc/trino 8081:8080 -n osclimate & \
  kubectl port-forward svc/minio 9001:9001 -n osclimate $
}

port_forward_airflow() {
    echo "Setting up port-forwarding for Airflow..."
    kubectl port-forward svc/$AIRFLOW_RELEASE-webserver 8080:8080 -n $NAMESPACE &
    echo "Airflow UI is accessible at http://localhost:8080"
}

port_forward_trino() {
    echo "Setting up port-forwarding for Trino..."
    kubectl port-forward svc/$TRINO_RELEASE 8081:8080 -n $NAMESPACE &
    echo "Trino UI is accessible at http://localhost:8081"
}

port_forward_minio() {
    echo "Setting up port-forwarding for MinIO..."
    kubectl port-forward svc/$MINIO_RELEASE 9000:9000 -n $NAMESPACE &
    echo "MinIO UI is accessible at http://localhost:9000"
}
delete_airflow(){

  echo "Deleting Airflow..."
  kubectl delete deployment airflow -n $NAMESPACE
  kubectl delete svc airflow-webserver -n $NAMESPACE
  kubectl delete pvc airflow-dags-pvc -n $NAMESPACE
  kubectl delete pv airflow-dags-pv -n $NAMESPACE
#   kubectl delete deployment redis -n $NAMESPACE
#   kubectl delete pv airflow-redis-pv -n $NAMESPACE


}
delete_trino(){
  echo "Deleting Trino..."
  kubectl delete deployment trino -n $NAMESPACE
  kubectl delete svc trino -n $NAMESPACE
  kubectl delete configmap trino-config -n $NAMESPACE

}

delete_minio(){
  echo "Deleting Minio..."
  kubectl delete deployment minio -n $NAMESPACE
  kubectl delete svc minio -n $NAMESPACE

}
# main
main() {
    # check_dependencies
    create_namespace

    # Parse input arguments
    case "$1" in
        deploy)
            case "$2" in
                airflow)
                    load_airflow_image
                    deploy_postgres
                    deploy_airflow
                    verify_deployment
                    ;;
                trino)
                    load_trino_image
                    deploy_hive_metastore
                    deploy_trino
                    verify_deployment
                    ;;
                minio)
                    load_minio_image
                    deploy_minio
                    verify_deployment
                    ;;
                all)
                    # load_airflow_image
                    deploy_postgres
                    # load_trino_image
                    deploy_hive_metastore
                    deploy_trino
                    # load_minio_image
                    deploy_minio
                    deploy_airflow
                    verify_deployment
                    ;;
                *)
                    echo "Usage: $0 deploy {airflow|trino|minio|all}"
                    exit 1
                    ;;
            esac
            ;;
        delete)
            case "$2" in
                airflow)
                    delete_airflow
                    ;;
                trino)
                    delete_trino
                    ;;
                minio)
                    delete_minio
                    ;;
                all)
                    echo "Deleting all deployments..."
                    delete_airflow
                    delete_trino
                    delete_minio

                    ;;
                *)
                    echo "Usage: $0 delete {airflow|trino|minio|all}"
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Usage: $0 {deploy|delete} {airflow|trino|minio|all}"
            exit 1
            ;;
    esac

    echo "Operation complete."
}

main "$@"