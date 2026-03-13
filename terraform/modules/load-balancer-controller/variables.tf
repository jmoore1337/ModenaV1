variable "eks_cluster_name"{
    description = "Name of the EKS cluster the ALB controller will watch"
    type        = string
}
    #^Example: "modena-dev-eks"
    #^Passed from dev/main.tf: module.eks.cluster_name

variable  "oidc_provider_arn"{
    description = "ARN of EKS OIDC provider (for pod IAM role trust relationship)"
    type        = string
     # Example: "arn:aws:iam::730335375020:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC123"
     # Passed from: module.eks.oidc_provider_arn
     # WHY: Used in the IAM role's assume_role_policy to allow pods to assume the role
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  # From: var.project_name
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  # From: var.environment
}

variable "vpc_id" {
  description = "VPC ID where ALBs will be created"
  type        = string
}