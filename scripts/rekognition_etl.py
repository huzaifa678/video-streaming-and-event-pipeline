import sys
import json
import logging
import boto3

from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import col, explode

from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger("GlueETL")
logger.setLevel(logging.INFO)

args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'S3_INPUT_PATH',
    'REDSHIFT_JDBC_URL',
    'REDSHIFT_SECRET_ARN',
    'SQS_QUEUE_URL'
])

SQS_QUEUE_URL = args['SQS_QUEUE_URL']

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

secrets_client = boto3.client("secretsmanager")
sqs_client = boto3.client("sqs")


def send_to_dlq(stage, error_msg, context_data=None):
    try:
        sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps({
                "job": args['JOB_NAME'],
                "stage": stage,
                "error": error_msg,
                "context": context_data
            })
        )
    except Exception as e:
        logger.error("Failed to send to DLQ", exc_info=True)


def get_secret():
    subsegment = None
    try:
        subsegment = xray_recorder.begin_subsegment("GetRedshiftSecret")

        secret_value = secrets_client.get_secret_value(
            SecretId=args['REDSHIFT_SECRET_ARN']
        )

        secret = json.loads(secret_value["SecretString"])

        subsegment.put_annotation("secret_fetched", True)

        return secret["username"], secret["password"]

    except Exception as e:
        if subsegment:
            subsegment.put_annotation("secret_error", str(e))
        raise

    finally:
        if subsegment:
            xray_recorder.end_subsegment()


try:
    s3_seg = xray_recorder.begin_subsegment("S3Read")

    df = spark.read.json(args['S3_INPUT_PATH'])

    input_count = df.count()

    s3_seg.put_annotation("input_count", input_count)
    xray_recorder.end_subsegment()

    logger.info(f"Loaded input records: {input_count}")

except Exception as e:
    if s3_seg:
        s3_seg.put_annotation("s3_read_error", str(e))
        xray_recorder.end_subsegment()

    send_to_dlq("S3_READ", str(e), {"path": args['S3_INPUT_PATH']})
    raise


try:
    transform_seg = xray_recorder.begin_subsegment("Transform")

    df_flat = df.select(
        col("InputInformation.KinesisVideo.StreamArn").alias("video_stream"),
        col("InputInformation.KinesisVideo.ProducerTimestamp").alias("timestamp"),
        explode(col("FaceSearchResponse")).alias("face_match")
    )

    df_final = df_flat.select(
        col("video_stream"),
        col("timestamp"),
        col("face_match.MatchedFaces")[0]["Face"]["FaceId"].alias("face_id"),
        col("face_match.MatchedFaces")[0]["Similarity"].alias("similarity")
    ).dropna()

    transform_seg.put_annotation("status", "success")

    xray_recorder.end_subsegment()

    logger.info("Transformation completed")

except Exception as e:
    if transform_seg:
        transform_seg.put_annotation("transform_error", str(e))
        xray_recorder.end_subsegment()

    send_to_dlq("TRANSFORM", str(e))
    raise


try:
    write_seg = xray_recorder.begin_subsegment("RedshiftWrite")

    username, password = get_secret()

    df_final.write \
        .format("jdbc") \
        .option("url", args['REDSHIFT_JDBC_URL']) \
        .option("dbtable", "video_events") \
        .option("user", username) \
        .option("password", password) \
        .option("driver", "com.amazon.redshift.jdbc.Driver") \
        .mode("append") \
        .save()

    write_seg.put_annotation("status", "success")

    xray_recorder.end_subsegment()

    logger.info("Successfully wrote to Redshift")

except Exception as e:
    if write_seg:
        write_seg.put_annotation("write_error", str(e))
        xray_recorder.end_subsegment()

    send_to_dlq("REDSHIFT_WRITE", str(e))
    raise


job.commit()