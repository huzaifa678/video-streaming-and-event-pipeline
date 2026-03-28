import os
import json
import logging
import boto3
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rekognition = boto3.client("rekognition")
sqs_client = boto3.client("sqs")

COLLECTION_ID = os.environ.get("COLLECTION_ID")
DLQ_URL = os.environ.get("SQS_QUEUE_URL")


def send_to_dlq(record, error_msg):
    if DLQ_URL:
        try:
            sqs_client.send_message(
                QueueUrl=DLQ_URL,
                MessageBody=json.dumps({
                    "record": record,
                    "error": error_msg
                })
            )
        except Exception as e:
            logger.error("Failed to send to DLQ", exc_info=True)
            xray_recorder.current_subsegment().add_exception(e)


def lambda_handler(event, context):
    processed = 0

    for record in event.get("Records", []):
        try:
            bucket = record["s3"]["bucket"]["name"]
            key = record["s3"]["object"]["key"]

            logger.info("Processing image", extra={
                "bucket": bucket,
                "key": key,
                "request_id": context.aws_request_id
            })

            with xray_recorder.in_subsegment("RekognitionIndexFaces"):
                response = rekognition.index_faces(
                    CollectionId=COLLECTION_ID,
                    Image={
                        "S3Object": {
                            "Bucket": bucket,
                            "Name": key
                        }
                    },
                    ExternalImageId=key.split("/")[-1],
                    DetectionAttributes=[]
                )

            face_records = response.get("FaceRecords", [])
            unindexed = response.get("UnindexedFaces", [])

            logger.info("Index result", extra={
                "face_indexed": len(face_records),
                "face_failed": len(unindexed)
            })

            if unindexed:
                logger.warning("face not indexed", extra={"details": unindexed})

            processed += 1

        except Exception as e:
            logger.error("Error processing image", exc_info=True)

            xray_recorder.current_segment().add_annotation(
                "index_faces_error", str(e)
            )

            send_to_dlq(record, str(e))

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Processed {processed} images"
        })
    }