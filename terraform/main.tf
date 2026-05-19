// Root module
module "storage_s3" {
  source = "./modules/storage_s3"

  environment               = var.environment
  user_uploads_bucket_name  = var.user_uploads_bucket_name
}
