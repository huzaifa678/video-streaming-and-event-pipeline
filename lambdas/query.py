import os
import json
import logging
import boto3
from sqlalchemy import create_engine, text
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REDSHIFT_HOST = os.environ["REDSHIFT_HOST"]
REDSHIFT_SECRET_ARN = os.environ["REDSHIFT_SECRET_ARN"]
DLQ_URL = os.environ.get("SQS_QUEUE_URL")

secrets_client = boto3.client("secretsmanager")
sqs_client = boto3.client("sqs")

def get_redshift_credentials():
    with xray_recorder.in_subsegment("GetSecrets"):
        secret_value = secrets_client.get_secret_value(SecretId=REDSHIFT_SECRET_ARN)
        secret = json.loads(secret_value["SecretString"])
        return secret["username"], secret["password"]

def get_engine():
    username, password = get_redshift_credentials()
    return create_engine(
        f"redshift+redshift_connector://{username}:{password}@{REDSHIFT_HOST}:5439/videoanalytics"
    )

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
    logger.info("API request received", extra={"event": event})

    query_params = event.get("queryStringParameters") or {}
    video_id = query_params.get("video_id")

    if not video_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "video_id required"})
        }

    try:
        query = text("""
            SELECT metadata, timestamp
            FROM video_events
            WHERE video_id = :video_id
            ORDER BY timestamp DESC
            LIMIT 1
        """)

        with xray_recorder.in_subsegment("RedshiftQuery"):
            engine = get_engine()
            with engine.connect() as conn:
                result = conn.execute(query, {"video_id": video_id}).fetchone()

        if result:
            metadata_json = json.loads(result["metadata"])
            timestamp_str = str(result["timestamp"])

            response_body = {
                "video_id": video_id,
                "timestamp": timestamp_str,
                "metadata": metadata_json
            }
        else:
            response_body = {"error": "No data found for video_id"}

        logger.info("Query success", extra={"video_id": video_id})

        return {
            "statusCode": 200,
            "body": json.dumps(response_body)
        }

    except Exception as e:
        logger.error("Error querying Redshift", exc_info=True)

        xray_recorder.current_segment().add_annotation(
            "query_error", str(e)
        )

        send_to_dlq(event, str(e))

        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }