terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.10.0, < 6.0.0"
    }
  }

  backend "s3" {
    bucket       = "video-ml-pipeline-terraform-state-ec371a2a"
    key          = "video-pipeline-arch/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  env          = var.env
}

module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  env          = var.env
}

module "messaging" {
  source       = "./modules/messaging"
  project_name = var.project_name
  env          = var.env
  kms_key_id   = module.networking.kms_key_id
}

module "analytics" {
  source                   = "./modules/analytics"
  project_name             = var.project_name
  env                      = var.env
  aws_region               = var.aws_region
  private_subnets          = module.networking.private_subnets
  redshift_secret_string   = module.storage.redshift_secret_string
  opensearch_secret_string = module.storage.opensearch_secret_string
  kms_key_arn              = module.networking.kms_key_arn
}

module "compute" {
  source         = "./modules/compute"
  project_name   = var.project_name
  lambda_memory  = var.lambda_memory
  lambda_timeout = var.lambda_timeout
  source_root    = path.module

  redshift_secret_arn = module.storage.redshift_secret_arn
  redshift_endpoint   = module.analytics.redshift_endpoint
  opensearch_endpoint = module.analytics.opensearch_endpoint
  opensearch_arn      = module.analytics.opensearch_arn

  kinesis_stream_name = module.messaging.kinesis_stream_name
  kinesis_stream_arn  = module.messaging.kinesis_stream_arn
  sqs_main_url        = module.messaging.sqs_main_url
  sqs_main_arn        = module.messaging.sqs_main_arn
  sqs_dlq_url         = module.messaging.sqs_dlq_id
  sqs_dlq_arn         = module.messaging.sqs_dlq_arn
  kvs_arn             = module.messaging.kvs_arn
  kms_key_arn         = module.networking.kms_key_arn

  analysis_results_bucket_arn = module.storage.analysis_results_bucket_arn
  face_images_bucket_arn      = module.storage.face_images_bucket_arn
  face_images_bucket_id       = module.storage.face_images_bucket_id
}

module "streaming" {
  source       = "./modules/streaming"
  project_name = var.project_name
  env          = var.env
  aws_region   = var.aws_region

  kvs_arn                  = module.messaging.kvs_arn
  video_events_kinesis_arn = module.messaging.kinesis_stream_arn

  analytics_bucket_arn        = module.storage.analytics_bucket_arn
  analysis_results_bucket_arn = module.storage.analysis_results_bucket_arn
  rekognition_raw_bucket_arn  = module.storage.rekognition_raw_bucket_arn

  rekognition_collection_id        = module.compute.rekognition_collection_id
  firehose_transform_function_name = module.compute.firehose_transform_function_name
  firehose_transform_arn           = module.compute.firehose_transform_arn
}

module "etl" {
  source       = "./modules/etl"
  project_name = var.project_name
  source_root  = path.module

  analysis_results_bucket_id   = module.storage.analysis_results_bucket_id
  analysis_results_bucket_arn  = module.storage.analysis_results_bucket_arn
  analysis_results_bucket_name = module.storage.analysis_results_bucket_name
  rekognition_raw_bucket_arn   = module.storage.rekognition_raw_bucket_arn
  rekognition_raw_bucket_name  = module.storage.rekognition_raw_bucket_name

  redshift_endpoint   = module.analytics.redshift_endpoint
  redshift_secret_arn = module.storage.redshift_secret_arn

  sqs_dlq_arn = module.messaging.sqs_dlq_arn
  sqs_dlq_url = module.messaging.sqs_dlq_url
}

module "api" {
  source                  = "./modules/api"
  project_name            = var.project_name
  env                     = var.env
  ingestion_function_name = module.compute.ingestion_function_name
  ingestion_invoke_arn    = module.compute.ingestion_invoke_arn
  query_invoke_arn        = module.compute.query_invoke_arn
}

module "observability" {
  source       = "./modules/observability"
  project_name = var.project_name
  sqs_dlq_name = module.messaging.sqs_dlq_name
}
