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

  depends_on = [
    aws_iam_role_policy.rekognition_kinesis_access
  ]

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
      collection_id        = aws_rekognition_collection.faces.id
      face_match_threshold = 85.0
    }
  }

  data_sharing_preference {
    opt_in = false 
  }

  provisioner "local-exec" {
    command = "sleep 20 && aws rekognition start-stream-processor --name ${self.name} --region ${var.aws_region}"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      data_sharing_preference
    ]
  }
}