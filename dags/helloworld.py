from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def hello():
    print("Hello, Airflow!")

with DAG(
    dag_id='helloworld_15min',
    start_date=datetime(2023, 1, 1),
    schedule="*/15 * * * *",  
    catchup=False,
) as dag:
    task = PythonOperator(
        task_id='say_hello',
        python_callable=hello,
    )
