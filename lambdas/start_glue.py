import os
import json
import boto3
import logging
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger()
logger.setLevel(logging.INFO)

GLUE_JOB_NAME = os.environ["GLUE_JOB_NAME"]
DLQ_URL = os.environ.get("SQS_QUEUE_URL")

glue_client = boto3.client("glue")
sqs_client = boto3.client("sqs")


def send_to_dlq(event, error_msg):
    if DLQ_URL:
        try:
            sqs_client.send_message(
                QueueUrl=DLQ_URL,
                MessageBody=json.dumps({
                    "event": event,
                    "error": error_msg
                })
            )
        except Exception as e:
            logger.error("Failed to send to DLQ", exc_info=True)
            xray_recorder.current_subsegment().add_exception(e)


def lambda_handler(event, context):
    logger.info("S3 event received", extra={"event": event})

    try:
        with xray_recorder.in_subsegment("StartGlueJob"):
            response = glue_client.start_job_run(
                JobName=GLUE_JOB_NAME
            )

        job_run_id = response["JobRunId"]

        logger.info("Glue job started", extra={
            "job_name": GLUE_JOB_NAME,
            "job_run_id": job_run_id,
            "request_id": context.aws_request_id
        })

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Glue job started",
                "job_run_id": job_run_id
            })
        }

    except Exception as e:
        logger.error("Failed to start Glue job", exc_info=True)

        xray_recorder.current_segment().add_annotation(
            "glue_start_error", str(e)
        )

        send_to_dlq(event, str(e))

        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Failed to start Glue job"
            })
        }