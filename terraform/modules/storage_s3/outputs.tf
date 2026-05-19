// Outputs for storage_s3 module
output "bucket_arn" {
  description = "ARN of the user uploads S3 bucket"
  value       = aws_s3_bucket.user_uploads.arn
}

output "bucket_name" {
  description = "Name of the user uploads S3 bucket"
  value       = aws_s3_bucket.user_uploads.id
}
