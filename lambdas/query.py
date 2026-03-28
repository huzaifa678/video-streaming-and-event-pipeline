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

_engine = None  


def get_redshift_credentials():
    subsegment = None

    try:
        subsegment = xray_recorder.begin_subsegment("GetSecrets")

        secret_value = secrets_client.get_secret_value(
            SecretId=REDSHIFT_SECRET_ARN
        )

        secret = json.loads(secret_value["SecretString"])

        subsegment.put_annotation("secret_fetched", True)

        return secret["username"], secret["password"]

    finally:
        if subsegment:
            xray_recorder.end_subsegment()


def get_engine():
    global _engine

    if _engine:
        return _engine

    username, password = get_redshift_credentials()

    _engine = create_engine(
        f"redshift+redshift_connector://{username}:{password}"
        f"@{REDSHIFT_HOST}:5439/videoanalytics",
        pool_pre_ping=True,
        pool_recycle=300
    )

    return _engine


def send_to_dlq(event, error_msg):
    try:
        if DLQ_URL:
            sqs_client.send_message(
                QueueUrl=DLQ_URL,
                MessageBody=json.dumps({
                    "event": event,
                    "error": error_msg
                })
            )
    except Exception as e:
        logger.error("Failed to send to DLQ", exc_info=True)


def lambda_handler(event, context):
    logger.info("API request received", extra={"event": event})

    query_params = event.get("queryStringParameters") or {}
    video_id = query_params.get("video_id")

    if not video_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "video_id required"})
        }

    db_subsegment = None

    try:
        query = text("""
            SELECT metadata, timestamp
            FROM video_events
            WHERE video_id = :video_id
            ORDER BY timestamp DESC
            LIMIT 1
        """)

        db_subsegment = xray_recorder.begin_subsegment("RedshiftQuery")
        db_subsegment.put_annotation("video_id", video_id)

        engine = get_engine()

        with engine.connect() as conn:
            result = conn.execute(query, {"video_id": video_id}).fetchone()

        xray_recorder.end_subsegment()
        db_subsegment = None

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

        if db_subsegment:
            db_subsegment.put_annotation("query_error", str(e))
            xray_recorder.end_subsegment()

        send_to_dlq(event, str(e))

        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }