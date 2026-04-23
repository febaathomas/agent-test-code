terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "app-logs-bucket-${random_id.suffix.hex}"
  force_destroy = false

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

  public_access_block {
    block_public_acls   = true
    block_public_policy = true
    ignore_public_acls  = true
    restrict_public_buckets = true
  }

  lifecycle_rule {
    id      = "log-retention"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  tags = {
    Environment = "dev"
    Project     = "agent-test"
    ManagedBy   = "terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
