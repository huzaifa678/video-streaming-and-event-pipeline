import base64
import json
import logging
import os

import boto3
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs_client = boto3.client("sqs")
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


def lambda_handler(event, context):
    segment = xray_recorder.current_segment()

    output = []

    logger.info(f"Received {len(event.get('records', []))} records")

    for record in event['records']:
        record_id = record['recordId']

        subsegment = None

        try:
            subsegment = xray_recorder.begin_subsegment("process_record")
            subsegment.put_annotation("recordId", record_id)

            payload = base64.b64decode(record['data']).decode('utf-8')

            logger.debug(f"Raw payload: {payload}")

            obj = json.loads(payload)

            subsegment.put_annotation("parsed", True)
            subsegment.put_metadata("record_sample", obj, "rekognition")

            cleaned = json.dumps(obj) + "\n"

            output_record = {
                'recordId': record_id,
                'result': 'Ok',
                'data': base64.b64encode(cleaned.encode('utf-8')).decode('utf-8')
            }

            logger.info(f"Processed record {record_id}")

        except Exception as e:
            logger.error(f"Failed record {record_id}: {str(e)}")

            if subsegment:
                subsegment.put_annotation("error", True)
                subsegment.put_metadata("error_message", str(e), "error")

            output_record = {
                'recordId': record_id,
                'result': 'Dropped',
                'data': record['data']
            }

            send_to_dlq(record, str(e))

        finally:
            if subsegment:
                xray_recorder.end_subsegment()

        output.append(output_record)

    logger.info(f"Processed batch: {len(output)} records")

    return {"records": output}