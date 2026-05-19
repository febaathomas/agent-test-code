// Root variables
variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "user_uploads_bucket_name" {
  description = "Name of the S3 bucket for user uploads"
  type        = string
  default     = "projname-user-uploads-${var.environment}"
}
