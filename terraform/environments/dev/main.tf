
# ═══════════════════════════════════════════════════════════════════════════════
# main.tf - DEV Environment
# ═══════════════════════════════════════════════════════════════════════════════
# This file CALLS modules and passes values from variables.tf
# NO hardcoded values here - everything comes from var.X
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# VPC MODULE
# ─────────────────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  # All values come from variables.tf - NOT hardcoded!
  environment        = var.environment        # → "dev"
  vpc_cidr           = var.vpc_cidr           # → "10.0.0.0/16"
  enable_nat_gateway = var.enable_nat_gateway # → false (saves $32/mo)
}

# ─────────────────────────────────────────────────────────────────────────────────
# ECR MODULE - Docker image registry
# ─────────────────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  environment           = var.environment
  project_name          = var.project_name
  image_retention_count = var.ecr_image_retention_count
  scan_on_push          = var.ecr_scan_on_push
}

# ═══════════════════════════════════════════════════════════════════════════════
# EKS MODULE - Kubernetes Cluster
# ═══════════════════════════════════════════════════════════════════════════════
# Where Modena containers actually RUN
#
# CONNECTION TO WHAT WE BUILT:
#   - Uses VPC and private subnets (from VPC module)
#   - Pulls images from ECR (from ECR module)
#   - App pods connect to RDS (from RDS module)
#
# CONNECTION TO YOUR DSNY EXPERIENCE:
#   - Winn/Bymx BFF ran on EKS
#   - Datadog monitors watched these pods
#   - Canary deployments targeted specific pods
# ═══════════════════════════════════════════════════════════════════════════════

# module "eks" {
#   source = "../../modules/eks"
#
#   environment        = var.environment
#   vpc_id             = module.vpc.vpc_id              # ← Uses VPC output!
#   private_subnet_ids = module.vpc.private_subnet_ids  # ← Uses VPC output!
#   node_instance_type = var.eks_node_instance_type
#   node_count         = var.eks_node_count
# }

# ═════════════════════════════════════════════════════════════════════════════════
# TEMPORARILY COMMENTED: IAM + SECRETS MODULES
# ═════════════════════════════════════════════════════════════════════════════════
# Work is saved in:
#   - terraform/modules/iam/ (complete)
#   - terraform/modules/secrets/ (complete)
#   - IAM-SECRETS-COMPLETE-FLOW.md (documentation)
#
# These will be re-enabled once we validate basic infrastructure.
# ═════════════════════════════════════════════════════════════════════════════════

 module "iam" {
   source = "../../modules/iam"
   cluster_name    = "${var.project_name}-${var.environment}-eks"
   environment     = var.environment
   aws_region      = var.aws_region
   aws_account_id  = var.aws_account_id
 }

 module "secrets" {
   source = "../../modules/secrets"
   environment        = var.environment
   cluster_name       = "${var.project_name}-${var.environment}-eks"
   aws_region         = var.aws_region
   eks_node_role_name = module.iam.eks_node_role_name
   db_username        = "modena_admin"
   db_password_length = 32
 }

module "eks" {
  source = "../../modules/eks"

  # Required
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids  # Nodes in private subnets
  eks_node_role_arn = module.iam.eks_node_role_arn
  
  # Cluster configuration
  cluster_version = var.eks_cluster_version

  # Node configuration
  node_instance_types = var.eks_node_instance_types
  node_desired_size   = var.eks_node_desired_size
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size

  tags = {
    Component = "compute"
  }
}
# ═══════════════════════════════════════════════════════════════════════════════
# RDS MODULE - PostgreSQL Database
# ═══════════════════════════════════════════════════════════════════════════════
# Stores Modena scan results: domains, DNS records, WHOIS data, etc.
#
# WHY RDS (not DynamoDB)?
#   - Relational data with JOINs (domains → scans → results)
#   - Complex queries needed for reporting
#   - ACID compliance for data integrity
#
# Remember: DynamoDB is for Terraform state LOCKING (simple key-value)
#           RDS is for APPLICATION DATA (relational, complex queries)
# ═══════════════════════════════════════════════════════════════════════════════

module "rds" {
  source = "../../modules/rds"

  # Required - passed from this environment's variables
  environment = var.environment
  vpc_id      = module.vpc.vpc_id               # ← From VPC module output!
  subnet_ids  = module.vpc.private_subnet_ids   # ← Private subnets for security
  
  # Database credentials
  # TODO: Uncomment when Secrets module is re-enabled
  # db_username = module.secrets.rds_username
  # db_password = module.secrets.rds_password
  #
  # For now, pass via environment variable:
  # export TF_VAR_db_password="temp-password-123"
  db_password = var.db_password
  
  # Instance configuration (from variables.tf defaults)
  instance_class    = var.rds_instance_class     # db.t3.micro
  allocated_storage = var.rds_allocated_storage  # 20 GB
  multi_az          = var.rds_multi_az           # false (save money in dev)
  
  # Dev-friendly settings
  skip_final_snapshot = true   # Don't wait for snapshot on destroy
  deletion_protection = false  # Allow easy cleanup
  
  # Security - will add EKS security group here later.
  # allowed_security_group_ids = [module.eks.node_security_group_id]
  
  tags = {
    Component = "database"
  }
}



# ALB controller module block will go HERE ← We add this
# ═══════════════════════════════════════════════════════════════════════════════
# ALB CONTROLLER MODULE - AWS Load Balancer Controller via IRSA
# ═══════════════════════════════════════════════════════════════════════════════
# What it does:
#   1. Creates IAM policy (ALB + EC2 permissions)
#   2. Creates IAM role (OIDC federated principal)
#   3. Creates Kubernetes service account (with IRSA annotation)
#   4. Deploys Helm release (AWS LB controller pods)
#
# WHY we need it:
#   Kubernetes Ingress resources don't create load balancers by themselves
#   ALB controller watches for Ingress → automatically creates AWS ALBs
#   Without this, pods are unreachable from outside the cluster
#
# Dependency chain:
#   EKS cluster must exist (to get oidc_provider_arn)
#   VPC must exist (to pass to controller)
# ═══════════════════════════════════════════════════════════════════════════════

module "alb_controller" {
  source = "../../modules/load-balancer-controller"

  # ──────────────────────────────────────────────────────────────────────────
  # Project identification
  # ──────────────────────────────────────────────────────────────────────────
  project_name = var.project_name  # → "modena"
  environment  = var.environment   # → "dev"

  # ──────────────────────────────────────────────────────────────────────────
  # EKS Cluster info (needed for IAM role trust relationship)
  # ──────────────────────────────────────────────────────────────────────────
  eks_cluster_name = module.eks.cluster_name
  # WHY? Controller needs to know which cluster to watch for Ingress resources
  # Example: "modena-dev-eks"

  oidc_provider_arn = module.eks.oidc_provider_arn
  # WHY? This is the CRITICAL piece for IRSA
  # The IAM role will trust JWTs signed by this OIDC provider
  # Example: "arn:aws:iam::730335375020:oidc-provider/oidc.eks.us-east-1..."
  # This comes from module.eks (created during EKS cluster creation)

  vpc_id = module.vpc.vpc_id
  # WHY? Controller needs to know which VPC to create ALBs in
  # Example: "vpc-0d1a2b3c4d5e6f7g8"

  depends_on = [
    module.eks,
    module.iam,
    module.secrets
  ]
  # WHY depends_on?
  # Terraform must create EKS cluster FIRST
  # → EKS creates OIDC provider
  # → OIDC provider ARN is available
  # → ALB controller can reference it in IAM role
  # Without this, Terraform will try to create them in wrong order
}

# ─────────────────────────────────────────────────────────────────────────────────
# OUTPUT: ALB Controller Info (for debugging)
# ─────────────────────────────────────────────────────────────────────────────────

output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB controller (IRSA)"
  value       = module.alb_controller.alb_controller_role_arn
}

output "alb_controller_service_account" {
  description = "Kubernetes service account name"
  value       = module.alb_controller.service_account_name
}
