terraform {         
  backend "s3" {    #defines where the terraform state file will be stored for STAGE environment
    bucket         = "modena-terraform-state" #the name of thes3 bucket
    key            = "stage/terraform.tfstate"    # path to the state file inside the bucket
    region         = "us-east-1"     #region of the s3 bucket
    dynamodb_table = "modena-terraform-locks" #specif
    encrypt        = true
  }
}