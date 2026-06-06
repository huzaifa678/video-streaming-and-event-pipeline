# State migration after module split.
# These tell Terraform: don't destroy/recreate, just rename the address.
# Safe to remove in a follow-up PR after a successful apply.

# networking
moved {
  from = module.vpc
  to   = module.networking.module.vpc
}
moved {
  from = aws_kms_key.video_stream_key
  to   = module.networking.aws_kms_key.video_stream_key
}
moved {
  from = aws_kms_alias.video_stream_alias
  to   = module.networking.aws_kms_alias.video_stream_alias
}
moved {
  from = data.aws_availability_zones.available
  to   = module.networking.data.aws_availability_zones.available
}

# storage
moved {
  from = aws_s3_bucket.analysis_results
  to   = module.storage.aws_s3_bucket.analysis_results
}
moved {
  from = aws_s3_bucket.rekognition_raw
  to   = module.storage.aws_s3_bucket.rekognition_raw
}
moved {
  from = aws_s3_bucket.analytics
  to   = module.storage.aws_s3_bucket.analytics
}
moved {
  from = aws_s3_bucket.face_images
  to   = module.storage.aws_s3_bucket.face_images
}
moved {
  from = aws_s3_bucket_notification.rekognition_eventbridge
  to   = module.storage.aws_s3_bucket_notification.rekognition_eventbridge
}
moved {
  from = aws_secretsmanager_secret.redshift
  to   = module.storage.aws_secretsmanager_secret.redshift
}
moved {
  from = aws_secretsmanager_secret_version.redshift
  to   = module.storage.aws_secretsmanager_secret_version.redshift
}
moved {
  from = random_password.redshift
  to   = module.storage.random_password.redshift
}
moved {
  from = aws_secretsmanager_secret.opensearch
  to   = module.storage.aws_secretsmanager_secret.opensearch
}
moved {
  from = aws_secretsmanager_secret_version.opensearch
  to   = module.storage.aws_secretsmanager_secret_version.opensearch
}
moved {
  from = random_password.opensearch
  to   = module.storage.random_password.opensearch
}

# messaging
moved {
  from = aws_sqs_queue.video_events_dlq
  to   = module.messaging.aws_sqs_queue.video_events_dlq
}
moved {
  from = aws_sqs_queue.video_events
  to   = module.messaging.aws_sqs_queue.video_events
}
moved {
  from = aws_kinesis_stream.video_events
  to   = module.messaging.aws_kinesis_stream.video_events
}
moved {
  from = aws_kinesis_video_stream.video_stream
  to   = module.messaging.aws_kinesis_video_stream.video_stream
}

# analytics
moved {
  from = aws_redshift_subnet_group.main
  to   = module.analytics.aws_redshift_subnet_group.main
}
moved {
  from = aws_redshift_cluster.main
  to   = module.analytics.aws_redshift_cluster.main
}
moved {
  from = null_resource.create_video_events_table
  to   = module.analytics.null_resource.create_video_events_table
}
moved {
  from = aws_opensearch_domain.video_events
  to   = module.analytics.aws_opensearch_domain.video_events
}

# compute - lambda + collection + notification + IAM
moved {
  from = data.archive_file.ingest_zip
  to   = module.compute.data.archive_file.ingest_zip
}
moved {
  from = data.archive_file.processing_zip
  to   = module.compute.data.archive_file.processing_zip
}
moved {
  from = data.archive_file.query_zip
  to   = module.compute.data.archive_file.query_zip
}
moved {
  from = data.archive_file.index_faces_zip
  to   = module.compute.data.archive_file.index_faces_zip
}
moved {
  from = data.archive_file.firehose_transform_zip
  to   = module.compute.data.archive_file.firehose_transform_zip
}
moved {
  from = data.archive_file.python_lib_zip
  to   = module.compute.data.archive_file.python_lib_zip
}
moved {
  from = aws_lambda_layer_version.python_dependencies
  to   = module.compute.aws_lambda_layer_version.python_dependencies
}
moved {
  from = aws_rekognition_collection.faces
  to   = module.compute.aws_rekognition_collection.faces
}
moved {
  from = aws_lambda_function.ingestion
  to   = module.compute.aws_lambda_function.ingestion
}
moved {
  from = aws_lambda_function.processing
  to   = module.compute.aws_lambda_function.processing
}
moved {
  from = aws_lambda_event_source_mapping.processing_kinesis_trigger
  to   = module.compute.aws_lambda_event_source_mapping.processing_kinesis_trigger
}
moved {
  from = aws_lambda_function.query_lambda
  to   = module.compute.aws_lambda_function.query_lambda
}
moved {
  from = aws_lambda_function.index_faces
  to   = module.compute.aws_lambda_function.index_faces
}
moved {
  from = aws_lambda_permission.allow_s3_face_images
  to   = module.compute.aws_lambda_permission.allow_s3_face_images
}
moved {
  from = aws_s3_bucket_notification.trigger_lambda
  to   = module.compute.aws_s3_bucket_notification.trigger_lambda
}
moved {
  from = aws_lambda_function.firehose_transform
  to   = module.compute.aws_lambda_function.firehose_transform
}
moved {
  from = aws_iam_role.lambda_exec
  to   = module.compute.aws_iam_role.lambda_exec
}
moved {
  from = aws_iam_role_policy_attachment.lambda_basic
  to   = module.compute.aws_iam_role_policy_attachment.lambda_basic
}
moved {
  from = aws_iam_role_policy_attachment.lambda_kinesis
  to   = module.compute.aws_iam_role_policy_attachment.lambda_kinesis
}
moved {
  from = aws_iam_role_policy_attachment.lambda_redshift
  to   = module.compute.aws_iam_role_policy_attachment.lambda_redshift
}
moved {
  from = aws_iam_role_policy_attachment.lambda_xray
  to   = module.compute.aws_iam_role_policy_attachment.lambda_xray
}
moved {
  from = aws_iam_policy.lambda_sqs_policy
  to   = module.compute.aws_iam_policy.lambda_sqs_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_sqs_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_sqs_attach
}
moved {
  from = aws_iam_policy.lambda_kvs_kms_policy
  to   = module.compute.aws_iam_policy.lambda_kvs_kms_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_kvs_kms_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_kvs_kms_attach
}
moved {
  from = aws_iam_policy.lambda_opensearch_policy
  to   = module.compute.aws_iam_policy.lambda_opensearch_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_opensearch_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_opensearch_attach
}
moved {
  from = aws_iam_policy.lambda_analysis_results_s3_policy
  to   = module.compute.aws_iam_policy.lambda_analysis_results_s3_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_ml_s3_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_ml_s3_attach
}
moved {
  from = aws_iam_policy.lambda_rekognition_policy
  to   = module.compute.aws_iam_policy.lambda_rekognition_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_rekognition_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_rekognition_attach
}
moved {
  from = aws_iam_role_policy.lambda_rekognition
  to   = module.compute.aws_iam_role_policy.lambda_rekognition
}
moved {
  from = aws_iam_policy.lambda_face_s3_policy
  to   = module.compute.aws_iam_policy.lambda_face_s3_policy
}
moved {
  from = aws_iam_role_policy_attachment.lambda_face_s3_attach
  to   = module.compute.aws_iam_role_policy_attachment.lambda_face_s3_attach
}

# streaming
moved {
  from = aws_kinesis_stream.rekognition_output
  to   = module.streaming.aws_kinesis_stream.rekognition_output
}
moved {
  from = aws_rekognition_stream_processor.video_processor
  to   = module.streaming.aws_rekognition_stream_processor.video_processor
}
moved {
  from = aws_kinesis_firehose_delivery_stream.video_events_to_s3
  to   = module.streaming.aws_kinesis_firehose_delivery_stream.video_events_to_s3
}
moved {
  from = aws_kinesis_firehose_delivery_stream.rekognition_to_s3
  to   = module.streaming.aws_kinesis_firehose_delivery_stream.rekognition_to_s3
}
moved {
  from = aws_lambda_permission.allow_firehose_invoke
  to   = module.streaming.aws_lambda_permission.allow_firehose_invoke
}
moved {
  from = aws_iam_role.rekognition_role
  to   = module.streaming.aws_iam_role.rekognition_role
}
moved {
  from = aws_iam_role_policy.rekognition_kinesis_access
  to   = module.streaming.aws_iam_role_policy.rekognition_kinesis_access
}
moved {
  from = aws_iam_role.firehose_role
  to   = module.streaming.aws_iam_role.firehose_role
}
moved {
  from = aws_iam_policy.firehose_policy
  to   = module.streaming.aws_iam_policy.firehose_policy
}
moved {
  from = aws_iam_role_policy_attachment.firehose_attach
  to   = module.streaming.aws_iam_role_policy_attachment.firehose_attach
}
moved {
  from = aws_iam_role_policy.firehose_lambda_access
  to   = module.streaming.aws_iam_role_policy.firehose_lambda_access
}

# etl
moved {
  from = aws_s3_object.rekognition_etl_script
  to   = module.etl.aws_s3_object.rekognition_etl_script
}
moved {
  from = aws_glue_job.rekognition_to_redshift
  to   = module.etl.aws_glue_job.rekognition_to_redshift
}
moved {
  from = aws_cloudwatch_log_group.sfn_glue_orchestrator
  to   = module.etl.aws_cloudwatch_log_group.sfn_glue_orchestrator
}
moved {
  from = aws_sfn_state_machine.glue_orchestrator
  to   = module.etl.aws_sfn_state_machine.glue_orchestrator
}
moved {
  from = aws_iam_role.glue_role
  to   = module.etl.aws_iam_role.glue_role
}
moved {
  from = aws_iam_policy.glue_policy
  to   = module.etl.aws_iam_policy.glue_policy
}
moved {
  from = aws_iam_role_policy_attachment.glue_attach
  to   = module.etl.aws_iam_role_policy_attachment.glue_attach
}
moved {
  from = aws_iam_role.sfn_glue_orchestrator
  to   = module.etl.aws_iam_role.sfn_glue_orchestrator
}
moved {
  from = aws_iam_policy.sfn_glue_orchestrator
  to   = module.etl.aws_iam_policy.sfn_glue_orchestrator
}
moved {
  from = aws_iam_role_policy_attachment.sfn_glue_orchestrator
  to   = module.etl.aws_iam_role_policy_attachment.sfn_glue_orchestrator
}
moved {
  from = aws_cloudwatch_event_rule.s3_rekognition_trigger
  to   = module.etl.aws_cloudwatch_event_rule.s3_rekognition_trigger
}
moved {
  from = aws_cloudwatch_event_target.sfn_target
  to   = module.etl.aws_cloudwatch_event_target.sfn_target
}
moved {
  from = aws_iam_role.eventbridge_invoke_sfn
  to   = module.etl.aws_iam_role.eventbridge_invoke_sfn
}
moved {
  from = aws_iam_role_policy.eventbridge_invoke_sfn
  to   = module.etl.aws_iam_role_policy.eventbridge_invoke_sfn
}

# api
moved {
  from = aws_apigatewayv2_api.video_api
  to   = module.api.aws_apigatewayv2_api.video_api
}
moved {
  from = aws_apigatewayv2_stage.stage
  to   = module.api.aws_apigatewayv2_stage.stage
}
moved {
  from = aws_apigatewayv2_integration.lambda_ingest
  to   = module.api.aws_apigatewayv2_integration.lambda_ingest
}
moved {
  from = aws_apigatewayv2_route.ingest_route
  to   = module.api.aws_apigatewayv2_route.ingest_route
}
moved {
  from = aws_apigatewayv2_integration.lambda_query
  to   = module.api.aws_apigatewayv2_integration.lambda_query
}
moved {
  from = aws_apigatewayv2_route.query_route
  to   = module.api.aws_apigatewayv2_route.query_route
}
moved {
  from = aws_lambda_permission.api_gateway
  to   = module.api.aws_lambda_permission.api_gateway
}

# observability
moved {
  from = aws_cloudwatch_log_group.lambda_ingestion_logs
  to   = module.observability.aws_cloudwatch_log_group.lambda_ingestion_logs
}
moved {
  from = aws_cloudwatch_log_group.lambda_processing_logs
  to   = module.observability.aws_cloudwatch_log_group.lambda_processing_logs
}
moved {
  from = aws_cloudwatch_log_group.lambda_glue_logs
  to   = module.observability.aws_cloudwatch_log_group.lambda_glue_logs
}
moved {
  from = aws_cloudwatch_metric_alarm.sqs_dlq_alarm
  to   = module.observability.aws_cloudwatch_metric_alarm.sqs_dlq_alarm
}
