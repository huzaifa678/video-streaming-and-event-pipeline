import sys
import json
import logging
import boto3
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import col, explode

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


# -------------------------
# Get DB credentials
# -------------------------
secret = json.loads(
    secrets_client.get_secret_value(
        SecretId=args['REDSHIFT_SECRET_ARN']
    )['SecretString']
)

username = secret["username"]
password = secret["password"]

try:
    df = spark.read.json(args['S3_INPUT_PATH'])
    logger.info(f"Read {df.count()} records from {args['S3_INPUT_PATH']}")
except Exception as e:
    logger.error("Failed to read S3 input", exc_info=True)
    send_to_dlq("S3_READ", str(e), {"path": args['S3_INPUT_PATH']})
    raise

try:
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

    logger.info(f"Transformed to {df_final.count()} records")

except Exception as e:
    logger.error("Transformation failed", exc_info=True)
    send_to_dlq("TRANSFORM", str(e))
    raise

try:
    df_final.write \
        .format("jdbc") \
        .option("url", args['REDSHIFT_JDBC_URL']) \
        .option("dbtable", "video_events") \
        .option("user", username) \
        .option("password", password) \
        .option("driver", "com.amazon.redshift.jdbc.Driver") \
        .mode("append") \
        .save()

    logger.info("Successfully wrote data to Redshift")

except Exception as e:
    logger.error("Redshift write failed", exc_info=True)
    send_to_dlq("REDSHIFT_WRITE", str(e))
    raise


job.commit()