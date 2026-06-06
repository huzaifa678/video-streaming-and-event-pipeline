resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_kinesis" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_redshift" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "${var.project_name}-lambda-sqs-policy"
  description = "Allow Lambda to send/receive messages from SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = [var.sqs_main_arn, var.sqs_dlq_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

resource "aws_iam_policy" "lambda_kvs_kms_policy" {
  name        = "${var.project_name}-lambda-kvs-kms"
  description = "Allow Lambda to access KVS stream and KMS decrypt"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesisvideo:GetMedia",
          "kinesisvideo:GetDataEndpoint",
          "kinesisvideo:ListStreams"
        ]
        Resource = var.kvs_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_kvs_kms_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_kvs_kms_policy.arn
}

resource "aws_iam_policy" "lambda_opensearch_policy" {
  name        = "${var.project_name}-lambda-opensearch"
  description = "Allow Lambda to push metadata to OpenSearch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["es:ESHttpPost", "es:ESHttpPut", "es:ESHttpGet"]
      Resource = "${var.opensearch_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_opensearch_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_opensearch_policy.arn
}

resource "aws_iam_policy" "lambda_analysis_results_s3_policy" {
  name        = "${var.project_name}-lambda-analysis-s3"
  description = "Allow Lambda to read rekognition predictions from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ]
      Resource = [
        var.analysis_results_bucket_arn,
        "${var.analysis_results_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ml_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_analysis_results_s3_policy.arn
}

resource "aws_iam_policy" "lambda_rekognition_policy" {
  name        = "${var.project_name}-lambda-rekognition"
  description = "Allow Lambda to analyze video using Rekognition"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "rekognition:StartLabelDetection",
        "rekognition:GetLabelDetection",
        "rekognition:StartFaceDetection",
        "rekognition:GetFaceDetection",
        "rekognition:StartContentModeration",
        "rekognition:GetContentModeration"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rekognition_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_rekognition_policy.arn
}

resource "aws_iam_role_policy" "lambda_rekognition" {
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rekognition:IndexFaces"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "lambda_face_s3_policy" {
  name = "${var.project_name}-lambda-face-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:GetObjectVersion"]
      Resource = "${var.face_images_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_face_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_face_s3_policy.arn
}
