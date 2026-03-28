import os
import json
import base64
import logging
from typing import Any, Dict
import boto3
import requests
from requests_aws4auth import AWS4Auth
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger()
logger.setLevel(logging.INFO)

OPENSEARCH_ENDPOINT = os.environ.get("OPENSEARCH_ENDPOINT")\

# manually using SQS for dead letter config
DLQ_URL = os.environ.get("SQS_QUEUE_URL")

sqs_client = boto3.client("sqs")
session = boto3.session.Session()
credentials = session.get_credentials()
region = os.environ["AWS_REGION"]

awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    "es",
    session_token=credentials.token
)

def send_to_dlq(record, error_msg):
    if DLQ_URL:
        sqs_client.send_message(
            QueueUrl=DLQ_URL,
            MessageBody=json.dumps({
                "record": record,
                "error": error_msg
            })
        )

def index_to_opensearch(data):
    if not OPENSEARCH_ENDPOINT:
        return

    url = f"https://{OPENSEARCH_ENDPOINT}/video-analytics-video-events/_doc"

    try:
        requests.post(
            url,
            auth=awsauth,
            json=data,
            headers={"Content-Type": "application/json"},
            timeout=2
        )
    except Exception as e:
        logger.error("OpenSearch indexing failed", exc_info=True)
        xray_recorder.current_subsegment().add_exception(e)


def lambda_handler(event, context):
    records_processed = 0

    for record in event.get("Records", []):
        try:
            payload = base64.b64decode(record["kinesis"]["data"])
            data: Dict[str, Any] = json.loads(payload)

            enriched = {
                "source": data.get("source", "unknown"),
                "video_id": data.get("video_id"),
                "timestamp": data.get("timestamp"),
                "ingested_at": context.aws_request_id,
                "payload": data
            }

            subsegment = xray_recorder.begin_subsegment("ProcessingEnrichment")
            subsegment.put_annotation("video_id", data.get("video_id", "unknown"))

            logger.info("Processed record", extra={"data": enriched})

            xray_recorder.end_subsegment()
            subsegment = None

            if OPENSEARCH_ENDPOINT:
                with xray_recorder.in_subsegment("OpenSearchIndex"):
                    index_to_opensearch(enriched)

            records_processed += 1

        except Exception as e:
            logger.error("Error processing record", exc_info=True)

            if subsegment:
                subsegment.put_annotation("processing_error", str(e))
                xray_recorder.end_subsegment()
                
            send_to_dlq(record, str(e))

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Processed {records_processed} records"
        })
    }