resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
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
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.video_events.arn,
          aws_sqs_queue.video_events_dlq.arn,
        ]
      }
    ]
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
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "kinesisvideo:GetMedia",
          "kinesisvideo:GetDataEndpoint",
          "kinesisvideo:ListStreams"
        ],
        Resource = aws_kinesis_video_stream.video_stream.arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.video_stream_key.arn
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
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet"
        ],
        Resource = "${aws_opensearch_domain.video_events.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_opensearch_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_opensearch_policy.arn
}

resource "aws_iam_policy" "lambda_analysis_results_s3_policy" {
  name        = "${var.project_name}-lambda-analysis-s3"
  description = "Allow Lambda to read recokgntion predictions model from S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.analysis_results.arn,
          "${aws_s3_bucket.analysis_results.arn}/*"
        ]
      }
    ]
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
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "rekognition:StartLabelDetection",
          "rekognition:GetLabelDetection",
          "rekognition:StartFaceDetection",
          "rekognition:GetFaceDetection",
          "rekognition:StartContentModeration",
          "rekognition:GetContentModeration"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_rekognition_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_rekognition_policy.arn
}

resource "aws_iam_role_policy" "lambda_rekognition" {
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "rekognition:IndexFaces"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "rekognition_role" {
  name = "${var.project_name}-rekognition-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "rekognition.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_face_s3_policy" {
  name = "${var.project_name}-lambda-face-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.face_images.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_face_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_face_s3_policy.arn
}

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_name}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "${var.project_name}-firehose-policy"
  description = "Allow Firehose to read from Kinesis and write to S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        Resource = [
          aws_kinesis_stream.video_events.arn,
          aws_kinesis_stream.rekognition_output.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.analysis_results.arn,
          "${aws_s3_bucket.analysis_results.arn}/*",
          aws_s3_bucket.rekognition_raw.arn,
          "${aws_s3_bucket.rekognition_raw.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_attach" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "glue.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "glue_policy" {
  name        = "${var.project_name}-glue-policy"
  description = "Glue job policy with S3, Redshift, Secrets, SQS, CloudWatch, X-Ray"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
        Resource = [aws_s3_bucket.analysis_results.arn, "${aws_s3_bucket.analysis_results.arn}/*", aws_s3_bucket.rekognition_raw.arn,"${aws_s3_bucket.rekognition_raw.arn}/*"]
      },
      {
        Effect = "Allow",
        Action = ["redshift:*", "redshift-data:*"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["secretsmanager:GetSecretValue"],
        Resource = aws_secretsmanager_secret.redshift.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents",
          "logs:DescribeLogGroups", "logs:DescribeLogStreams"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"],
        Resource = aws_sqs_queue.video_events_dlq.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_policy.arn
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
        Resource = aws_kinesis_video_stream.video_stream.arn
      },

      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.rekognition_output.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_glue_start" {
  name = "lambda-glue-start-job"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun"
        ]
        Resource = aws_glue_job.rekognition_to_redshift.arn
      }
    ]
  })
}