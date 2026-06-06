output "rekognition_output_kinesis_arn" {
  value = aws_kinesis_stream.rekognition_output.arn
}

output "firehose_rekognition_arn" {
  value = aws_kinesis_firehose_delivery_stream.rekognition_to_s3.arn
}
