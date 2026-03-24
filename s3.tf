resource "aws_s3_bucket" "analysis_results" {
  bucket = "${var.project_name}-video-results-storage"

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "rekognition_raw" {
  bucket = "${var.project_name}-rekognition-raw"

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project_name}-analytics"

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