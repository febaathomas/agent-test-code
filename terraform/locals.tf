// Common tags for resources
locals {
  common_tags = {
    Environment = var.environment
    Project     = "projname"
  }
}
