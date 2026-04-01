import sys
import json
import logging
import boto3

from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import col, explode_outer

from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

logger = logging.getLogger("GlueETL")
logger.setLevel(logging.INFO)

# Fetching Job Arguments
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

xray_recorder.begin_segment(args['JOB_NAME'])


def safe_annotate(segment, key, value):
    if segment:
        segment.put_annotation(key, value)


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
    except Exception:
        logger.error("Failed to send to DLQ", exc_info=True)


def get_secret():
    subsegment = None
    try:
        subsegment = xray_recorder.begin_subsegment("GetRedshiftSecret")

        secret_value = secrets_client.get_secret_value(
            SecretId=args['REDSHIFT_SECRET_ARN']
        )
        secret = json.loads(secret_value["SecretString"])

        safe_annotate(subsegment, "secret_fetched", True)
        return secret["username"], secret["password"]

    except Exception as e:
        safe_annotate(subsegment, "secret_error", str(e))
        raise
    finally:
        if subsegment:
            xray_recorder.end_subsegment()


load_seg = None
try:
    load_seg = xray_recorder.begin_subsegment("LoadData")

    raw_df = spark.read.text(args['S3_INPUT_PATH'])

    logger.info("Loaded raw text data from S3")
    json_rdd = raw_df.rdd.flatMap(lambda row: row.value.split("}{"))

    json_rdd = json_rdd.map(lambda x: x if x.startswith("{") else "{" + x)
    json_rdd = json_rdd.map(lambda x: x if x.endswith("}") else x + "}")

    df = spark.read.json(json_rdd)

    logger.info("Converted concatenated JSON into structured DataFrame")
    logger.info(f"Raw record count: {df.count()}")

    safe_annotate(load_seg, "load_status", "success")
except Exception as e:
    safe_annotate(load_seg, "load_error", str(e))
    send_to_dlq("LOAD", str(e))
    raise
finally:
    if load_seg:
        xray_recorder.end_subsegment()


transform_seg = None
try:
    transform_seg = xray_recorder.begin_subsegment("Transform")

    df1 = df.select(
        col("InputInformation.KinesisVideo.StreamArn").alias("video_stream"),
        col("InputInformation.KinesisVideo.ProducerTimestamp").alias("timestamp"),
        explode_outer("FaceSearchResponse").alias("fsr")
    )

    df2 = df1.select(
        "video_stream",
        "timestamp",
        explode_outer("fsr.MatchedFaces").alias("match")
    )

    df_final = df2.select(
        "video_stream",
        "timestamp",
        col("match.Face.FaceId").alias("face_id"),
        col("match.Similarity").alias("similarity")
    ).dropna(subset=["face_id", "similarity"])

    logger.info(f"Final record count: {df_final.count()}")

    safe_annotate(transform_seg, "transform_status", "success")

except Exception as e:
    safe_annotate(transform_seg, "transform_error", str(e))
    send_to_dlq("TRANSFORM", str(e))
    raise
finally:
    if transform_seg:
        xray_recorder.end_subsegment()


load_rs_seg = None
try:
    load_rs_seg = xray_recorder.begin_subsegment("LoadToRedshift")

    username, password = get_secret()

    df_final.write \
        .format("jdbc") \
        .option("url", args['REDSHIFT_JDBC_URL']) \
        .option("dbtable", "public.face_matches") \
        .option("user", username) \
        .option("password", password) \
        .option("driver", "com.amazon.redshift.jdbc.Driver") \
        .mode("append") \
        .save()

    safe_annotate(load_rs_seg, "load_rs_status", "success")
    logger.info("Data loaded into Redshift successfully")

except Exception as e:
    safe_annotate(load_rs_seg, "load_rs_error", str(e))
    send_to_dlq("LOAD_REDSHIFT", str(e))
    raise
finally:
    if load_rs_seg:
        xray_recorder.end_subsegment()


job.commit()
xray_recorder.end_segment()