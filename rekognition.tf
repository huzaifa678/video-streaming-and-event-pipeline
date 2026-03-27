resource "aws_rekognition_collection" "faces" {
  collection_id = "my-face-collection"
}

resource "aws_kinesis_stream" "rekognition_output" {
  name             = "${var.project_name}-rekognition-results"
  shard_count      = var.env == "dev" ? 1 : 2
  retention_period = 24
}

resource "aws_rekognition_stream_processor" "video_processor" {
  name     = "${var.project_name}-video-processor"
  role_arn = aws_iam_role.rekognition_role.arn

  input {
    kinesis_video_stream {
      arn = aws_kinesis_video_stream.video_stream.arn   
    }
  }

  output {
    kinesis_data_stream {
      arn = aws_kinesis_stream.rekognition_output.arn
    }
  }

  settings {
    face_search {
      collection_id        = aws_rekognition_collection.faces.collection_id
      face_match_threshold = 85.0
    }
  }

  data_sharing_preference {
    opt_in = false 
  }

  lifecycle {
    ignore_changes = [
      data_sharing_preference
    ]
  }
}

resource "aws_s3_object" "user_face" {
  bucket = aws_s3_bucket.face_images.id
  key    = "faces/user1.jpg"
  source = "${path.module}/faces/user1.jpg"
  etag   = filemd5("${path.module}/faces/myface.jpg")
}