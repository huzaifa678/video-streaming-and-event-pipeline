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
    'REDSHIFT_SECRET_ARN'
])

sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

secrets_client = boto3.client("secretsmanager")
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
    logger.error(f"Failed to read S3 input: {e}", exc_info=True)
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

    logger.info(f"Transformed to {df_final.count()} flattened records")
except Exception as e:
    logger.error(f"Failed to transform Rekognition data: {e}", exc_info=True)
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
    logger.error(f"Failed to write to Redshift: {e}", exc_info=True)
    raise

job.commit()