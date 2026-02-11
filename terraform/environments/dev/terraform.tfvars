# ═══════════════════════════════════════════════════════════════════════════════
# terraform.tfvars - Actual Values for DEV Environment
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHAT IS THIS FILE?
# ──────────────────
# variables.tf DEFINES what variables exist and their types.
# terraform.tfvars ASSIGNS actual values to those variables.
#
# WHY SEPARATE FILES?
# ───────────────────
# variables.tf is the SAME across all environments (defines the schema)
# terraform.tfvars is DIFFERENT per environment (dev vs stage vs prod values)
#
# SECURITY NOTE:
# ──────────────
# This file can contain sensitive values.
# Do NOT commit sensitive values to git.
# Use environment variables or Secrets Manager for passwords.
#
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# GENERAL
# ─────────────────────────────────────────────────────────────────────────────────
aws_region     = "us-east-1"
aws_account_id = "730335375020"
environment    = "dev"
project_name   = "modena"

# ─────────────────────────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────────────────────────
vpc_cidr = "10.0.0.0/16"


# ─────────────────────────────────────────────────────────────────────────────────
# EKS
# ─────────────────────────────────────────────────────────────────────────────────
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size   = 1
eks_node_min_size       = 1
eks_node_max_size       = 3
eks_node_disk_size      = 20
eks_cluster_version     = "1.32"  # Step 2: upgrade 1.31 -> 1.32 (final, standard support)

# ─────────────────────────────────────────────────────────────────────────────────
# RDS
# ─────────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# RDS
# ─────────────────────────────────────────────────────────────────────────────
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20

# NAT
enable_nat_gateway = true

# Jenkins Configuration
jenkins_allowed_cidrs = ["108.207.130.60/32"]
key_name              = "jenkins-key"

