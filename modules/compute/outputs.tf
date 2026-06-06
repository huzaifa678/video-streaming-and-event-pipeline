output "lambda_exec_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

output "rekognition_collection_id" {
  value = aws_rekognition_collection.faces.id
}

output "ingestion_function_name" {
  value = aws_lambda_function.ingestion.function_name
}

output "ingestion_invoke_arn" {
  value = aws_lambda_function.ingestion.invoke_arn
}

output "ingestion_execution_arn_prefix" {
  value = aws_lambda_function.ingestion.arn
}

output "processing_function_name" {
  value = aws_lambda_function.processing.function_name
}

output "query_function_name" {
  value = aws_lambda_function.query_lambda.function_name
}

output "query_invoke_arn" {
  value = aws_lambda_function.query_lambda.invoke_arn
}

output "index_faces_function_name" {
  value = aws_lambda_function.index_faces.function_name
}

output "firehose_transform_function_name" {
  value = aws_lambda_function.firehose_transform.function_name
}

output "firehose_transform_arn" {
  value = aws_lambda_function.firehose_transform.arn
}
