// Variables for storage_s3 module
variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "user_uploads_bucket_name" {
  description = "S3 bucket name for user uploads"
  type        = string
}
