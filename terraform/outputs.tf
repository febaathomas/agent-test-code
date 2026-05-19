// Root outputs
output "user_uploads_bucket_arn" {
  description = "ARN of the user uploads S3 bucket"
  value       = module.storage_s3.bucket_arn
}
