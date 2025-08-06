FROM apache/airflow:2.9.3
ENV PATH="/home/airflow/.local/bin:$PATH"
RUN pip install "apache-airflow==2.9.3" --no-cache-dir apache-airflow-providers-trino
RUN pip install pandas openpyxl pyarrow boto3 apache-airflow-providers-openlineage