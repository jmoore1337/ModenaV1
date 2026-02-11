terraform {             #Where to store the terraform state file for DEV environment
  backend "s3" {
    bucket = "modena-terraform-state-730335375020" #name of the S3 bucket
    key = "dev/terraform.tfstate" #path to the state file inside the bucket
    region = "us-east-1"      #AWS region where the bucket is located  
    dynamodb_table = "modena-terraform-locks" #tells terraform use a DynamoDB table with this NAME for locking."
    use_lockfile = true      #use lockfile for state locking (new parameter)
    encrypt = true           #enable server-side encryption for the state file
  }
}