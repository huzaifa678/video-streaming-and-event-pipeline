resource "aws_iam_role" "rekognition_role" {
  name = "${var.project_name}-rekognition-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rekognition.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "rekognition_kinesis_access" {
  name = "${var.project_name}-rekognition-kinesis-access"
  role = aws_iam_role.rekognition_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesisvideo:GetDataEndpoint",
          "kinesisvideo:GetMedia",
          "kinesisvideo:GetMediaForFragmentList",
          "kinesisvideo:DescribeStream"
        ]
        Resource = var.kvs_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = aws_kinesis_stream.rekognition_output.arn
      }
    ]
  })
}

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "${var.project_name}-firehose-policy"
  description = "Allow Firehose to read from Kinesis and write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = [
          var.video_events_kinesis_arn,
          aws_kinesis_stream.rekognition_output.arn
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:PutObjectAcl", "s3:ListBucket"]
        Resource = [
          var.analysis_results_bucket_arn,
          "${var.analysis_results_bucket_arn}/*",
          var.rekognition_raw_bucket_arn,
          "${var.rekognition_raw_bucket_arn}/*",
          var.analytics_bucket_arn,
          "${var.analytics_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_iam_role_policy" "firehose_lambda_access" {
  name = "firehose-lambda-access"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction", "lambda:GetFunctionConfiguration"]
      Resource = var.firehose_transform_arn
    }]
  })
}
