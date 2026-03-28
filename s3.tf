resource "aws_s3_bucket" "analysis_results" {
  bucket = "${var.project_name}-video-results-storage"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "rekognition_raw" {
  bucket = "${var.project_name}-rekognition-raw"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project_name}-analytics"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_object" "rekognition_etl_script" {
  bucket = aws_s3_bucket.analysis_results.id
  key    = "scripts/rekognition_etl.py"  
  source = "${path.module}/scripts/rekognition_etl.py"  
  etag   = filemd5("${path.module}/scripts/rekognition_etl.py")
}

resource "aws_s3_bucket" "face_images" {
  bucket = "${var.project_name}-face-image"

  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.face_images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.index_faces.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3
  ]
}