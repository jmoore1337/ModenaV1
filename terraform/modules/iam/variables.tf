variable "cluster_name" {
    description = "EKS cluster name used for role naming"
    type        = string
}
variable "environment" {
    description = "Deployment environment (e.g., dev, stage, prod)"
    type        = string
}
variable "aws_region" {
    description = "AWS region"  
    type        = string
}
variable "aws_account_id" {
    description = "AWS account ID"
    type        = string
}