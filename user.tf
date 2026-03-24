resource "aws_iam_policy" "terraform_user_policy" {
  name        = "${var.project_name}-terraform-full-access"
  description = "Full access for Terraform user to manage Lambda, KVS, KMS, SQS, Redshift, OpenSearch, API Gateway, CloudWatch, Rekognition, Firehose, S3, and IAM roles/policies"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iam:*",

          "lambda:*",

          "sqs:*",

          "kinesisvideo:*",

          "kinesis:*",

          "firehose:*",

          "s3:*",

          "redshift:*",

          "es:*",

          "rekognition:*",

          "apigateway:*",
          "apigatewayv2:*",

          "cloudwatch:*",
          "logs:*",

          "kms:*",

          "secretsmanager:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "terraform_attach" {
  user       = "terraform"
  policy_arn = aws_iam_policy.terraform_user_policy.arn
}