from pendulum import datetime
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import (
    KubernetesPodOperator,
)

with DAG(
    dag_id="hello_python_test",
    schedule="@once",
    start_date=datetime(2024, 11, 5),
) as dag:
    hello_python_test = KubernetesPodOperator(
    namespace='osclimate',
    image="hello-world:latest",
    name="hello-python",
    #image_pull_policy="Always",
    image_pull_policy="IfNotPresent",
    task_id="hello-python",
    in_cluster=True,
    is_delete_operator_pod=False,
    get_logs=True,
    service_account_name='airflow',
    #hostnetwork=False,
    startup_timeout_seconds=30
    )
        
    hello_python_test