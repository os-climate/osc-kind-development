import os
import urllib.request
import zipfile
import pendulum
import pandas as pd
import logging

from airflow import DAG
from airflow.decorators import task
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from botocore.exceptions import NoCredentialsError
from botocore.exceptions import ClientError
from boto3.exceptions import S3UploadFailedError 

with DAG(
    "generic_ingestion_dag",
    start_date=pendulum.datetime(2021, 1, 1, tz="UTC"),
    schedule_interval="@daily",
    catchup=False,
) as dag:

    @task
    def download_file_task(url: str, local_zip: str) -> str:
        """
        Downloads the ZIP file from the given URL and saves it locally.
        Returns the local file path.
        """
        if os.path.exists(local_zip):
            os.remove(local_zip)
        logging.info(f"Downloading file from {url} to {local_zip}")
        with urllib.request.urlopen(url) as response, open(local_zip, "wb") as f:
            f.write(response.read())
        logging.info(f"File downloaded and saved at {local_zip}")
        return local_zip

    @task
    def extract_convert_task(
        local_zip: str,
        file_format: str,
        skip_rows: int,
        delimiter: str,
        quotechar: str,
        output_file: str,
    ) -> str:
        """
        Opens the downloaded ZIP file, extracts and converts the first valid file,
        and writes the resulting data to a local output file.
        Returns the output file path.
        """
        extracted_bytes = None
        with zipfile.ZipFile(local_zip, "r") as zf:
            for file_name in zf.namelist():
                # Process CSV file
                if file_format.lower() == "csv" and file_name.endswith(".csv"):
                    logging.info(f"Found CSV file: {file_name}. Processing...")
                    with zf.open(file_name) as f:
                        try:
                            df = pd.read_csv(f, skiprows=skip_rows, sep=delimiter, quotechar=quotechar)
                        except pd.errors.EmptyDataError:
                            logging.warning(f"Empty CSV file {file_name} encountered. Skipping...")
                            continue
                        if df.empty:
                            logging.warning(f"CSV file {file_name} is empty after reading. Skipping...")
                            continue
                        logging.info(f"Converting CSV file {file_name} to Parquet format...")
                        extracted_bytes = df.to_parquet(compression="gzip")
                        break
                # Process Parquet file
                elif file_format.lower() == "parquet" and file_name.endswith(".parquet"):
                    logging.info(f"Found Parquet file: {file_name}. Processing...")
                    with zf.open(file_name) as f:
                        data = f.read()
                        if not data:
                            logging.warning(f"Parquet file {file_name} is empty. Skipping...")
                            continue
                        extracted_bytes = data
                        break

        if extracted_bytes is None:
            raise ValueError(f"No valid {file_format} file found in {local_zip}")

        with open(output_file, "wb") as out_f:
            out_f.write(extracted_bytes)
        logging.info(f"Extracted and converted file saved to {output_file}")
        return output_file

    @task
    def upload_to_s3_task(local_file: str, s3_bucket: str, s3_key: str, aws_conn_id: str = "s3") -> str:
        """
        Uploads the local file to S3 and returns the S3 key.
        Checks if the bucket exists and creates it if necessary.
        """
        s3_hook = S3Hook(aws_conn_id=aws_conn_id)
        s3_client = s3_hook.get_conn()

        # Check if bucket exists
        try:
            s3_client.head_bucket(Bucket=s3_bucket)
            logging.info(f"Bucket '{s3_bucket}' exists.")
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "404" or error_code == "NoSuchBucket":
                logging.info(f"Bucket '{s3_bucket}' does not exist. Attempting to create it.")
                try:
                    s3_client.create_bucket(Bucket=s3_bucket)
                    logging.info(f"Bucket '{s3_bucket}' created successfully.")
                except Exception as create_exc:
                    logging.error(f"Failed to create bucket '{s3_bucket}': {create_exc}")
                    raise
            else:
                logging.error(f"Error checking bucket '{s3_bucket}': {e}")
                raise

        try:
            s3_hook.load_file(
                filename=local_file,
                bucket_name=s3_bucket,
                key=s3_key,
                replace=True,
            )
            logging.info(f"Uploaded {local_file} to s3://{s3_bucket}/{s3_key}")
        except NoCredentialsError:
            conn = s3_hook.get_connection(aws_conn_id)
            logging.error(
                f"Unable to locate AWS credentials for connection '{aws_conn_id}'. "
                f"Connection details: {conn}"
            )
            raise
        except S3UploadFailedError as e:
            # Log detailed error information for debugging InvalidAccessKeyId errors
            conn = s3_hook.get_connection(aws_conn_id)
            logging.error(
                f"Failed to upload {local_file} to s3://{s3_bucket}/{s3_key}: {e}\n"
                f"Check that the AWS Access Key Id in connection '{aws_conn_id}' is correct.\n"
                f"Connection details: ID: {conn.conn_id}, Host: {conn.host}, Extra: {conn.extra}"
            )
            raise 
        except Exception as e:
            logging.error(f"Error uploading file to s3://{s3_bucket}/{s3_key}: {e}")
            raise
        return s3_key

    # Parameters – these could also be pulled from Airflow Variables or a configuration file
    url = "https://api.worldbank.org/v2/country/all/indicator/NY.GDP.MKTP.CD;NY.GDP.MKTP.PP.CD;SP.POP.TOTL?source=2&downloadformat=csv"  # Replace with your actual URL
    local_zip = "worldbank_generic.zip"
    file_format = "csv"  # Options: "csv" or "parquet"
    skip_rows = 4
    delimiter = ","
    quotechar = '"'
    output_file = "/tmp/converted_data.parquet"  # Local file path for extracted/converted data
    s3_bucket = "pcaf"  # Replace with your target S3 bucket
    s3_key = "raw/worldbank_generic/worldbank.parquet"  # Target S3 key for the uploaded file



    # Define task dependencies
    downloaded_zip = download_file_task(url, local_zip)
    converted_file = extract_convert_task(downloaded_zip, file_format, skip_rows, delimiter, quotechar, output_file)
    s3_key_reference = upload_to_s3_task(converted_file, s3_bucket, s3_key)
