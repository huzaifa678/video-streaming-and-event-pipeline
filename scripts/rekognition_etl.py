import sys
import json
import logging
import boto3

from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job
from pyspark.sql.functions import col, explode_outer
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, LongType,
    ArrayType, BooleanType,
)

from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()

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

xray_recorder.begin_segment(args['JOB_NAME'])


def safe_annotate(segment, key, value):
    if segment:
        segment.put_annotation(key, value)


# Explicit schema for Rekognition streaming face search response
bounding_box = StructType([
    StructField("Width", DoubleType(), True),
    StructField("Height", DoubleType(), True),
    StructField("Left", DoubleType(), True),
    StructField("Top", DoubleType(), True),
])

landmark = StructType([
    StructField("Type", StringType(), True),
    StructField("X", DoubleType(), True),
    StructField("Y", DoubleType(), True),
])

pose = StructType([
    StructField("Roll", DoubleType(), True),
    StructField("Yaw", DoubleType(), True),
    StructField("Pitch", DoubleType(), True),
])

quality = StructType([
    StructField("Brightness", DoubleType(), True),
    StructField("Sharpness", DoubleType(), True),
])

detected_face = StructType([
    StructField("BoundingBox", bounding_box, True),
    StructField("Confidence", DoubleType(), True),
    StructField("Landmarks", ArrayType(landmark), True),
    StructField("Pose", pose, True),
    StructField("Quality", quality, True),
])

matched_face_inner = StructType([
    StructField("FaceId", StringType(), True),
    StructField("BoundingBox", bounding_box, True),
    StructField("ImageId", StringType(), True),
    StructField("ExternalImageId", StringType(), True),
    StructField("Confidence", DoubleType(), True),
    StructField("IndexFacesModelVersion", StringType(), True),
])

matched_face = StructType([
    StructField("Similarity", DoubleType(), True),
    StructField("Face", matched_face_inner, True),
])

face_search_entry = StructType([
    StructField("DetectedFace", detected_face, True),
    StructField("MatchedFaces", ArrayType(matched_face), True),
])

kinesis_video = StructType([
    StructField("StreamArn", StringType(), True),
    StructField("FragmentNumber", StringType(), True),
    StructField("ServerTimestamp", DoubleType(), True),
    StructField("ProducerTimestamp", DoubleType(), True),
    StructField("FrameOffsetInSeconds", DoubleType(), True),
])

input_information = StructType([
    StructField("KinesisVideo", kinesis_video, True),
])

stream_processor_info = StructType([
    StructField("Status", StringType(), True),
])

rekognition_schema = StructType([
    StructField("InputInformation", input_information, True),
    StructField("StreamProcessorInformation", stream_processor_info, True),
    StructField("FaceSearchResponse", ArrayType(face_search_entry), True),
])


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

    df = (
        spark.read
        .schema(rekognition_schema)
        .option("mode", "PERMISSIVE")
        # Tolerate the "no files yet" case so first runs don't fail.
        .json(args['S3_INPUT_PATH'])
    )

    raw_count = df.count()
    logger.info(f"Loaded data from {args['S3_INPUT_PATH']}")
    logger.info(f"Raw record count: {raw_count}")

    safe_annotate(load_seg, "load_status", "success")
    safe_annotate(load_seg, "raw_record_count", raw_count)

except Exception as e:
    safe_annotate(load_seg, "load_error", str(e))
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
        explode_outer("FaceSearchResponse").alias("fsr"),
    )

    df2 = df1.select(
        "video_stream",
        "timestamp",
        explode_outer("fsr.MatchedFaces").alias("match"),
    ).filter(col("match").isNotNull())

    df_final = df2.select(
        "video_stream",
        "timestamp",
        col("match.Face.FaceId").alias("face_id"),
        col("match.Similarity").alias("similarity"),
    ).dropna(subset=["face_id", "similarity"])

    final_count = df_final.count()
    logger.info(f"Final record count: {final_count}")

    safe_annotate(transform_seg, "transform_status", "success")
    safe_annotate(transform_seg, "final_record_count", final_count)

except Exception as e:
    safe_annotate(transform_seg, "transform_error", str(e))
    raise
finally:
    if transform_seg:
        xray_recorder.end_subsegment()


load_rs_seg = None
try:
    load_rs_seg = xray_recorder.begin_subsegment("LoadToRedshift")

    if final_count == 0:
        logger.info("No matched face rows; skipping Redshift write.")
        safe_annotate(load_rs_seg, "load_rs_status", "skipped_empty")
    else:
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
    raise
finally:
    if load_rs_seg:
        xray_recorder.end_subsegment()


job.commit()
xray_recorder.end_segment()
