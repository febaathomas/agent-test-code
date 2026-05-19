// S3 bucket for user uploads
resource "aws_s3_bucket" "user_uploads" {
  bucket = var.user_uploads_bucket_name
  acl    = "private"

  tags = merge(
    local.common_tags,
    {
      Purpose = "user-uploads"
    }
  )

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "expire-objects"
    enabled = true
    expiration {
      days = 365
    }
  }
}
