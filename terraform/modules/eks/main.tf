# ═══════════════════════════════════════════════════════════════════════════════
# EKS MODULE - MAIN
# ═══════════════════════════════════════════════════════════════════════════════
# Creates:
#   1. EKS Cluster (control plane)
#   2. Node Group (worker nodes)
#   3. Security Group (network rules)
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP FOR EKS CLUSTER
# ─────────────────────────────────────────────────────────────────────────────────
# Additional security group for cluster communication
# EKS creates a default one, but we add custom rules here

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-eks-cluster-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# EKS CLUSTER
# ─────────────────────────────────────────────────────────────────────────────────
# The control plane - managed by AWS
# This is what "kubectl" talks to

resource "aws_eks_cluster" "main" {
  name     = "${local.name_prefix}-eks"
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # ─────────────────────────────────────────────────────────────────
  # NETWORK CONFIGURATION
  # ─────────────────────────────────────────────────────────────────
  vpc_config {
    subnet_ids              = var.subnet_ids  # Private subnets
    endpoint_private_access = true            # API accessible from within VPC
    endpoint_public_access  = true            # API accessible from internet (for kubectl)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    
    # ═══════════════════════════════════════════════════════════════
    # INTERVIEW TIP: endpoint_public_access
    # ═══════════════════════════════════════════════════════════════
    # true  = You can run kubectl from your laptop
    # false = kubectl only works from within VPC (more secure for prod)
    #
    # For dev: true (easier to work with)
    # For prod: false + VPN or bastion host
    # ═══════════════════════════════════════════════════════════════
  }

  # ─────────────────────────────────────────────────────────────────
  # LOGGING (Optional but recommended)
  # ─────────────────────────────────────────────────────────────────
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  # Sends control plane logs to CloudWatch
  # Useful for debugging auth issues and API calls

  # Change support type to STANDARD (cluster is at 1.31, will upgrade to 1.32 - both in standard support)
  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-eks"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Ensure IAM role is created before cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# ─────────────────────────────────────────────────────────────────────────────────
# EKS NODE GROUP
# ─────────────────────────────────────────────────────────────────────────────────
# Worker nodes - EC2 instances that run your pods
# These are the actual compute resources

# ─────────────────────────────────────────────────────────────────────────────────
# EKS NODE GROUP - AL2023 (replaces old "main" node group)
# ─────────────────────────────────────────────────────────────────────────────────
# Amazon Linux 2023 = No extended support charges
# Old "main" node group will be destroyed

resource "aws_eks_node_group" "al2023" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-node-group-al2023"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.subnet_ids

  # ─────────────────────────────────────────────────────────────────
  # INSTANCE CONFIGURATION
  # ─────────────────────────────────────────────────────────────────
  instance_types = var.node_instance_types  # ["t3.medium"]
  disk_size      = var.node_disk_size       # 20 GB
  capacity_type  = "ON_DEMAND"              # or "SPOT" for cost savings
  ami_type       = "AL2023_x86_64_STANDARD" # Amazon Linux 2023 (NO extended support charges)
  
  
  # ─────────────────────────────────────────────────────────────────
  # SCALING CONFIGURATION
  # ─────────────────────────────────────────────────────────────────
  # ═══════════════════════════════════════════════════════════════════
  # AUTO-SCALING EXPLAINED:
  # ═══════════════════════════════════════════════════════════════════
  # desired_size = Start with this many nodes
  # min_size     = Never go below this (even if no traffic)
  # max_size     = Never exceed this (cost protection)
  #
  # Cluster Autoscaler (separate component) watches for pending pods
  # and adds/removes nodes within these bounds.
  #
  # CONNECTION TO DSNY: Your Bymx monitors watched pod health.
  # When pods couldn't schedule, autoscaler added nodes!
  # ═══════════════════════════════════════════════════════════════════
  
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }
  
  # ─────────────────────────────────────────────────────────────────
  # UPDATE CONFIGURATION
  # ─────────────────────────────────────────────────────────────────
  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = var.environment
    NodeGroup   = "al2023"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-node-group-al2023"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# OIDC PROVIDER (For Pod IAM Roles)
# ─────────────────────────────────────────────────────────────────────────────────
# Allows pods to assume IAM roles (not just nodes)
# Example: Your backend pod can assume a role to access Secrets Manager

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${local.name_prefix}-eks-oidc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}