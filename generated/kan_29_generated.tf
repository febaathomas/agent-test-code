#########################
# Provider
#########################
provider "aws" {
  region = var.region
}

#########################
# Variables
#########################
variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID (used for unique bucket name)."
  type        = string
}

variable "region" {
  description = "AWS region where resources will be created."
  type        = string
}

variable "bucket_name_prefix" {
  description = "Prefix for the log bucket name."
  type        = string
  default     = "app-logs"
}

variable "encryption_type" {
  description = "Server‑side encryption algorithm. \"AES256\" or \"aws:kms\"."
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_type)
    error_message = "encryption_type must be \"AES256\" or \"aws:kms\"."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN (required when encryption_type = \"aws:kms\")."
  type        = string
  default     = null
}

variable "versioning_enabled" {
  description = "Enable S3 versioning."
  type        = bool
  default     = true
}

variable "lifecycle_transition_days" {
  description = "Days before transition to STANDARD_IA."
  type        = number
  default     = 30
}

variable "lifecycle_expiration_days" {
  description = "Days before permanent deletion."
  type        = number
  default     = 90
}

variable "access_logging_enabled" {
  description = "Create a separate bucket for S3 server‑access logs."
  type        = bool
  default     = false
}

variable "app_role_arn" {
  description = "ARN of the IAM role that writes logs to the bucket."
  type        = string
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for the CloudWatch alarm."
  type        = string
}

variable "alarm_threshold_bytes" {
  description = "Bucket size (bytes) that triggers the alarm."
  type        = number
  default     = 1073741824   # 1 GiB
}

variable "tags" {
  description = "Default tags applied to all resources."
  type        = map(string)
  default = {
    Project = "KAN"
    Owner   = "Shraddhesh10"
  }
}

#########################
# Locals
#########################
locals {
  log_bucket_name = "${var.bucket_name_prefix}-${var.environment}-${var.account_id}"
  access_log_bucket_name = "app-logs-access-${var.environment}-${var.account_id}"
}

#########################
# Main Log Bucket
#########################
resource "aws_s3_bucket" "log_bucket" {
  bucket = local.log_bucket_name
  acl    = "private"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Purpose     = "ApplicationLogs"
    },
  )
}

resource "aws_s3_bucket_public_access_block" "log_bucket_pab" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_enc" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.encryption_type
      kms_master_key_id = var.encryption_type == "aws:kms" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_versioning" "log_bucket_ver" {
  bucket = aws_s3_bucket.log_bucket.id
  status = var.versioning_enabled ? "Enabled" : "Suspended"
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_lc" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "transition-and-expiration"
    status = "Enabled"

    transition {
      days          = var.lifecycle_transition_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.lifecycle_expiration_days
    }
  }
}

resource "aws_s3_bucket_policy" "log_bucket_policy" {
  bucket = aws_s3_bucket.log_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAppRolePutObject"
        Effect    = "Allow"
        Principal = {
          AWS = var.app_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.log_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = var.encryption_type
          }
        }
      },
      {
        Sid       = "DenyUnencryptedPutObject"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.log_bucket.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = var.encryption_type
          }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.log_bucket_pab]
}

#########################
# Optional Access‑Log Bucket
#########################
resource "aws_s3_bucket" "access_log_bucket" {
  count  = var.access_logging_enabled ? 1 : 0
  bucket = local.access_log_bucket_name
  acl    = "log-delivery-write"

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Purpose     = "S3AccessLogs"
    },
  )
}

resource "aws_s3_bucket_logging" "log_bucket_logging" {
  count = var.access_logging_enabled ? 1 : 0

  bucket = aws_s3_bucket.log_bucket.id

  target_bucket = aws_s3_bucket.access_log_bucket[0].id
  target_prefix = "access-logs/"

  depends_on = [aws_s3_bucket.access_log_bucket]
}

#########################
# CloudWatch Alarm
#########################
resource "aws_cloudwatch_metric_alarm" "log_spike_alarm" {
  alarm_name          = "${local.log_bucket_name}-size-spike"
  alarm_description   = "Alarm when bucket size exceeds ${var.alarm_threshold_bytes} bytes."
  namespace           = "AWS/S3"
  metric_name         = "BucketSizeBytes"
  dimensions = {
    BucketName = aws_s3_bucket.log_bucket.id
    StorageType = "StandardStorage"
  }
  statistic           = "Average"
  period              = 86400   # 1 day
  evaluation_periods  = 1
  threshold           = var.alarm_threshold_bytes
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [var.alarm_sns_topic_arn]

  treat_missing_data = "notBreaching"
}

#########################
# Outputs
#########################
output "log_bucket_name" {
  description = "Name of the application log bucket."
  value       = aws_s3_bucket.log_bucket.id
}

output "log_bucket_arn" {
  description = "ARN of the application log bucket."
  value       = aws_s3_bucket.log_bucket.arn
}

output "access_log_bucket_name" {
  description = "Name of the optional access‑log bucket (empty if not created)."
  value       = var.access_logging_enabled ? aws_s3_bucket.access_log_bucket[0].id : ""
}

output "cloudwatch_alarm_arn" {
  description = "ARN of the CloudWatch alarm monitoring bucket size."
  value       = aws_cloudwatch_metric_alarm.log_spike_alarm.arn
}