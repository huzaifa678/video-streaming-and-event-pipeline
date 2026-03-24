import os
import json
from typing import Any, Dict
import boto3
import logging
from botocore.exceptions import ClientError
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

KINESIS_STREAM = os.environ["KINESIS_STREAM"]
SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]

kinesis_client = boto3.client("kinesis")
sqs_client = boto3.client("sqs")

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("Lambda invoked", extra={"event": event})

    try:
        try:
            body: Dict[str, Any] = json.loads(event.get("body", "{}"))
            logger.info(f"Parsed body type: {type(body)}", extra={"body": body})
        except json.JSONDecodeError:
            body = {}

        with xray_recorder.in_subsegment("KinesisPutRecord") as sub:
            try:
                kinesis_client.put_record(
                    StreamName=KINESIS_STREAM,
                    Data=json.dumps(body),
                    PartitionKey=body.get("video_id", "default")
                )
                logger.info("Sent event to Kinesis", extra={"body": body})
            except ClientError as e:
                logger.error("Failed to put record to Kinesis", exc_info=True)
                sub.add_exception(e)
                raise

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Event ingested"})
        }

    except Exception as e:
        logger.exception("Unhandled exception in ingestion Lambda")
        raise