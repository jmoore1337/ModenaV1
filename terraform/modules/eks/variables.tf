# ═══════════════════════════════════════════════════════════════════════════════
# EKS MODULE - VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════
# Inputs received from environments/dev/main.tf
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS will be created"
  type        = string
  # From: module.vpc.vpc_id
}

variable "subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
  # From: module.vpc.private_subnet_ids
  # WHY private? Worker nodes shouldn't be directly internet-accessible
}

# ─────────────────────────────────────────────────────────────────────────────────
# OPTIONAL VARIABLES
# ─────────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "modena"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
  # ─────────────────────────────────────────────────────────────────
  # VERSION NOTES:
  # ─────────────────────────────────────────────────────────────────
  # 1.29 = Current stable (as of late 2024)
  # Always pin a version! Don't let AWS auto-upgrade.
  # Upgrades can break apps - do them intentionally.
  # ─────────────────────────────────────────────────────────────────
}

variable "node_instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
  # ─────────────────────────────────────────────────────────────────
  # INSTANCE TYPE CHEAT SHEET:
  # ─────────────────────────────────────────────────────────────────
  # t3.small  = 2 vCPU, 2GB RAM  - ~$15/mo - Too small for k8s
  # t3.medium = 2 vCPU, 4GB RAM  - ~$30/mo - Good for dev ✅
  # t3.large  = 2 vCPU, 8GB RAM  - ~$60/mo - Good for stage
  # t3.xlarge = 4 vCPU, 16GB RAM - ~$120/mo - Production
  #
  # WHY t3.medium minimum?
  # Kubernetes system pods (coredns, kube-proxy) need ~1GB
  # Your app pods need room too. t3.small runs out fast.
  # ─────────────────────────────────────────────────────────────────
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
  # Dev: 1 node (save money)
  # Prod: 3+ nodes (high availability across AZs)
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes (for auto-scaling)"
  type        = number
  default     = 3
  # Auto-scaler can add nodes up to this limit during high traffic
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
  # 20GB is fine for dev. Docker images + logs.
  # Increase for prod if running many containers.
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "eks_node_role_arn" {
  description = "ARN of the EKS node IAM role (created by IAM module)"
  type        = string
}