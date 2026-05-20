variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = var.bucket_name

  tags = {
    Environment = "dev"
    Project     = "agent-test"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_encryption" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_public" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "expire-objects"
    status = "Enabled"

    filter {}
    expiration {
      days = 90
    }
  }
}
