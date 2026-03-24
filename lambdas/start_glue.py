import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

GLUE_JOB_NAME = os.environ["GLUE_JOB_NAME"]

glue_client = boto3.client("glue")

def lambda_handler(event, context):
    logger.info(f"S3 event received: {event}")

    try:
        # Start Glue job
        response = glue_client.start_job_run(JobName=GLUE_JOB_NAME)
        logger.info(f"Started Glue job {GLUE_JOB_NAME}: {response['JobRunId']}")
        return {
            "statusCode": 200,
            "body": f"Glue job started: {response['JobRunId']}"
        }
    except Exception as e:
        logger.exception("Failed to start Glue job")
        raise e