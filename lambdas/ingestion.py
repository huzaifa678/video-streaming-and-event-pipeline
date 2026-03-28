import os
import json
import logging
from typing import Any, Dict
import boto3
from botocore.exceptions import ClientError
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

KINESIS_STREAM = os.environ["KINESIS_STREAM"]
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]

kinesis_client = boto3.client("kinesis")
sqs_client = boto3.client("sqs")

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def send_to_dlq(event, error_msg):
    try:
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "event": event,
                "error": error_msg
            })
        )
    except Exception as e:
        logger.error("Failed to send to DLQ", exc_info=True)
        xray_recorder.current_subsegment().add_exception(e)


def lambda_handler(event, context):
    logger.info("Lambda invoked", extra={"event": event})

    body: Dict[str, Any] = {}

    try:
        raw_body = event.get("body", "{}")

        try:
            body = json.loads(raw_body) if isinstance(raw_body, str) else raw_body
        except json.JSONDecodeError:
            logger.warning("Invalid JSON body, defaulting to empty dict")
            body = {}

        logger.info("Parsed request body", extra={"body": body})
        
        with xray_recorder.in_subsegment("KinesisPutRecord"):
            response = kinesis_client.put_record(
                StreamName=KINESIS_STREAM,
                Data=json.dumps(body),
                PartitionKey=str(body.get("video_id", "default"))
            )

        logger.info("Sent event to Kinesis", extra={
            "sequence_number": response.get("SequenceNumber"),
            "partition_key": body.get("video_id", "default")
        })

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Event ingested",
                "sequence_number": response.get("SequenceNumber")
            })
        }

    except ClientError as e:
        logger.error("AWS ClientError in ingestion Lambda", exc_info=True)

        subsegment = xray_recorder.begin_subsegment("KinesisClientError")
        subsegment.put_annotation("kinesis_error", str(e))
        xray_recorder.end_subsegment()


        send_to_dlq(event, str(e))

        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Kinesis ingestion failed"})
        }

    except Exception as e:
        logger.error("Unhandled exception in ingestion Lambda", exc_info=True)

        subsegment = xray_recorder.begin_subsegment("IngestionError")
        subsegment.put_annotation("ingestion_error", str(e))
        xray_recorder.end_subsegment()

        send_to_dlq(event, str(e))

        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }