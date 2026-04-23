# Terraform configuration for KAN-29: S3 bucket for application logs
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# S3 bucket to store application logs
resource "aws_s3_bucket" "app_logs" {
  bucket = "app-logs-bucket"

  # Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Versioning
  versioning {
    enabled = true
  }

  # Server-side encryption (AES-256)
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Lifecycle rules
  lifecycle_rule {
    id      = "transition-to-ia"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  # Tags
  tags = {
    Environment = "dev"
    Project     = "agent-test"
    ManagedBy   = "terraform"
  }
}
