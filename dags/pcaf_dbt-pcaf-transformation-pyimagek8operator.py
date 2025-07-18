from pendulum import datetime
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import (
    KubernetesPodOperator,
)

with DAG(
    dag_id="dbt-pcaf-transformation",
    schedule="@once",
    start_date=datetime(2024, 11, 5),
) as dag:
    image_job_run = KubernetesPodOperator(
    namespace='osclimate',
    image="dbt-pcaf-transformation",
    name="dbt-pcaf-transformation",
    #image_pull_policy="Always",
    image_pull_policy="IfNotPresent",
    task_id="dbt-pcaf-transformation",
    in_cluster=True,
    is_delete_operator_pod=False,
    get_logs=True,
    service_account_name='airflow',
    #hostnetwork=False,
    startup_timeout_seconds=30
    )
        
    image_job_run