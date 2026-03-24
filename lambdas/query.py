import os
import json
import logging
import boto3
from sqlalchemy import create_engine, text

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REDSHIFT_HOST = os.environ["REDSHIFT_HOST"]
REDSHIFT_SECRET_ARN = os.environ["REDSHIFT_SECRET_ARN"]

secrets_client = boto3.client("secretsmanager")

def get_redshift_credentials():
    secret_value = secrets_client.get_secret_value(SecretId=REDSHIFT_SECRET_ARN)
    secret = json.loads(secret_value["SecretString"])
    return secret["username"], secret["password"]

username, password = get_redshift_credentials()

engine = create_engine(
    f"redshift+redshift_connector://{username}:{password}@{REDSHIFT_HOST}:5439/videoanalytics"
)

def lambda_handler(event, context):
    logger.info(f"API request received: {event}")
    
    query_params = event.get("queryStringParameters") or {}
    video_id = query_params.get("video_id")
    
    if not video_id:
        return {"statusCode": 400, "body": json.dumps({"error": "video_id required"})}
    
    try:
        query = text("""
            SELECT metadata, timestamp
            FROM video_events
            WHERE video_id = :video_id
            ORDER BY timestamp DESC
            LIMIT 1
        """)

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

        return {"statusCode": 200, "body": json.dumps(response_body)}

    except Exception as e:
        logger.exception("Error querying Redshift")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}