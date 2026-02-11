variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (used for naming resources)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "db_username" {
  description = "RDS database username"
  type        = string
  default     = "modena_admin"
}

variable "db_password_length" {
  description = "Length of randomly generated RDS password"
  type        = number
  default     = 32
}

variable "eks_node_role_name" {
  description = "Name of EKS node role"
  type        = string
}
