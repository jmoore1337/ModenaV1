# ═══════════════════════════════════════════════════════════════════════════════
# JENKINS MODULE - variables.tf
# ═══════════════════════════════════════════════════════════════════════════════

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Jenkins will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Jenkins EC2"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Jenkins (your IP)"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name for kubectl configuration"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.medium"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}