// Backend configuration (example using S3)
terraform {
  backend "s3" {
    bucket = "projname-terraform-state"
    key    = "global/terraform.tfstate"
    region = var.region
  }
}
