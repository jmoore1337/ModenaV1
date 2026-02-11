# ═══════════════════════════════════════════════════════════════════════════════
# VPC Module - Variables
# ═══════════════════════════════════════════════════════════════════════════════
# 
# WHY VARIABLES?
# - Makes the module REUSABLE across environments (dev/stage/prod)
# - You pass different values from environments/dev/main.tf vs environments/prod/main.tf
# - Same module code, different configurations
#
# INTERVIEW TIP: "We use variables to make modules environment-agnostic.
# The module doesn't know if it's dev or prod - it just uses whatever values are passed in."
# ═══════════════════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  # WHY /16?
  # - Gives us 65,536 IP addresses
  # - Plenty of room for subnets
  # - CIDR math: /16 = 2^(32-16) = 2^16 = 65,536 IPs
  # 
  # INTERVIEW QUESTION YOU MIGHT GET:
  # "How many IPs in a /24?" → 256 (2^8)
  # "How many IPs in a /16?" → 65,536 (2^16)
}

variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  
  # WHY 2 AZs?
  # - High availability: if us-east-1a fails, 1b keeps running
  # - ALB REQUIRES minimum 2 subnets in different AZs
  # - RDS Multi-AZ needs 2 AZs for failover
  #
  # FROM YOUR INTERVIEW: Target groups route to pods in MULTIPLE AZs
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # WHY /24?
  # - 256 IPs per subnet (more than enough for ALB, NAT Gateway)
  # - Public subnets don't need many IPs - just load balancers and NAT
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
  
  # WHY PRIVATE SUBNETS?
  # - EKS worker nodes go here (no direct internet access = more secure)
  # - RDS goes here (database should NEVER be public)
  # - At Cisco you used Wiz to find security issues - public databases are a TOP finding!
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
  
  # WHY NAT GATEWAY?
  # - Private subnets can't reach internet directly (no IGW route)
  # - But EKS nodes need to pull Docker images from ECR!
  # - NAT Gateway: outbound YES, inbound NO
  # 
  # COST WARNING: NAT Gateway costs ~$0.045/hour (~$32/month)
  # For dev, you might disable this to save money
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}