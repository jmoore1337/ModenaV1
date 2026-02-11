# ═══════════════════════════════════════════════════════════════════════════════
# EKS MODULE - IAM ROLES
# ═══════════════════════════════════════════════════════════════════════════════
# EKS needs TWO IAM roles:
#   1. Cluster Role  - Permissions for EKS control plane
#   2. Node Role     - Permissions for worker nodes (EC2s)
#
# WHY SEPARATE ROLES?
# Principle of least privilege. Cluster needs different permissions than nodes.
# This is the security pattern you'd see flagged in Wiz if done wrong!
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─────────────────────────────────────────────────────────────────────────────────
# EKS CLUSTER IAM ROLE
# ─────────────────────────────────────────────────────────────────────────────────
# This role is ASSUMED BY the EKS service itself (not your nodes)
# Allows EKS to manage AWS resources on your behalf

# Trust policy: "Who can assume this role?"
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]  # Only EKS service can assume this
    }
    actions = ["sts:AssumeRole"]
  }
}

# Create the role
resource "aws_iam_role" "eks_cluster" {
  name               = "${local.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  
  tags = {
    Name        = "${local.name_prefix}-eks-cluster-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach AWS managed policy for EKS clusters
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
  # This policy allows EKS to:
  # - Create/manage ENIs for pod networking
  # - Describe EC2 resources
  # - Manage security groups
}

# ─────────────────────────────────────────────────────────────────────────────────
# EKS NODE ROLE
# ─────────────────────────────────────────────────────────────────────────────────
# NOTE: Node role is now created by the IAM module and passed as inputs.
# This centralizes IAM management in one place (DRY principle).
# The role is passed via var.eks_node_role_arn in the module input.