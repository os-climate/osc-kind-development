from pendulum import datetime
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import (
    KubernetesPodOperator,
)

with DAG(
    dag_id="pcaf_ingestion-dim-countries",
    schedule="@once",
    start_date=datetime(2024, 11, 5),
) as dag:
    image_job_run = KubernetesPodOperator(
    namespace='osclimate',
    image="dim-countries-job",
    name="dim-countries-job",
    #image_pull_policy="Always",
    image_pull_policy="IfNotPresent",
    task_id="dim-countries-job",
    in_cluster=True,
    is_delete_operator_pod=False,
    get_logs=True,
    service_account_name='airflow',
    #hostnetwork=False,
    startup_timeout_seconds=30
    )
        
    image_job_run