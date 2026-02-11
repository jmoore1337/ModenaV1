# ═══════════════════════════════════════════════════════════════════════════════
# JENKINS MODULE USAGE - environments/dev/jenkins.tf
# ═══════════════════════════════════════════════════════════════════════════════
#
# This file shows how to use the Jenkins module in your dev environment.
# Copy this to your terraform/environments/dev/ directory.
#
# PREREQUISITES:
# 1. VPC module must be deployed (need vpc_id, public_subnet_id)
# 2. EKS module must be deployed (need cluster name for kubectl)
# 3. EC2 Key Pair must exist in AWS
#
# INTERVIEW TIP:
# "I reference outputs from other modules using module.vpc.vpc_id.
# This creates dependencies - Terraform knows to create VPC before Jenkins."
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# JENKINS MODULE
# ─────────────────────────────────────────────────────────────────────────────
module "jenkins" {
  source = "../../modules/jenkins"

  # Project identification
  project_name = var.project_name  # "modena"
  environment  = var.environment   # "dev"

  # Network configuration (from VPC module)
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]  # First public subnet

  # IMPORTANT: Restrict access to YOUR IP only!
  # Find your IP: curl ifconfig.me
  # Format: ["YOUR.IP.ADDRESS/32"]
  allowed_cidr_blocks = var.jenkins_allowed_cidrs

  # SSH Key Pair (must exist in AWS)
  key_name = var.key_name

  # EKS cluster name (for kubectl configuration)
  eks_cluster_name = module.eks.cluster_name

  # Optional: Override defaults
  # instance_type = "t3.large"  # If you need more power
  # volume_size   = 100         # If you need more storage
}

# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES NEEDED
# ─────────────────────────────────────────────────────────────────────────────
# Add these to your terraform/environments/dev/variables.tf:

# variable "jenkins_allowed_cidrs" {
#   description = "CIDR blocks allowed to access Jenkins (your IP)"
#   type        = list(string)
#   # Example: ["1.2.3.4/32"]
# }
#
# variable "key_name" {
#   description = "EC2 Key Pair name for SSH access"
#   type        = string
# }

# ─────────────────────────────────────────────────────────────────────────────
# OUTPUTS
# ─────────────────────────────────────────────────────────────────────────────
# Add these to your terraform/environments/dev/outputs.tf:

output "jenkins_url" {
  description = "Jenkins web UI URL"
  value       = module.jenkins.jenkins_url
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = module.jenkins.ssh_command
}

output "jenkins_initial_password_command" {
  description = "Command to get Jenkins initial admin password"
  value       = module.jenkins.initial_password_command
}

output "jenkins_github_webhook_url" {
  description = "URL for GitHub webhook configuration"
  value       = module.jenkins.github_webhook_url
}

output "jenkins_iam_role_arn" {
  description = "Jenkins IAM role ARN (needed for EKS aws-auth ConfigMap)"
  value       = module.jenkins.jenkins_iam_role_arn
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS AWS-AUTH CONFIGMAP UPDATE
# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANT: After Jenkins is deployed, you must add its IAM role to the
# EKS aws-auth ConfigMap. Otherwise, Jenkins can't deploy to the cluster!
#
# Run this kubectl command (or add to your EKS module):
#
# kubectl edit configmap aws-auth -n kube-system
#
# Add this under mapRoles:
#
#   - rolearn: <jenkins_iam_role_arn from output>
#     username: jenkins
#     groups:
#       - system:masters
#
# Or use eksctl:
# eksctl create iamidentitymapping \
#   --cluster modena-dev-eks \
#   --arn <jenkins_iam_role_arn> \
#   --username jenkins \
#   --group system:masters

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM.TFVARS EXAMPLE
# ─────────────────────────────────────────────────────────────────────────────
# Add to terraform/environments/dev/terraform.tfvars:
#
# jenkins_allowed_cidrs = ["YOUR.IP.ADDRESS/32"]  # Get from: curl ifconfig.me
# key_name              = "your-key-pair-name"     # Must exist in AWS EC2
