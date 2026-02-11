terraform {
  backend "s3" {
    bucket         = "modena-terraform-state"
    key            = "prod/terraform.tfstate"    # ← PROD-specific path
    region         = "us-east-1"
    dynamodb_table = "modena-terraform-locks"
    encrypt        = true
  }
}