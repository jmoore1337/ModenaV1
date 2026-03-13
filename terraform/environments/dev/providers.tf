# ═══════════════════════════════════════════════════════════════════════════════
# providers.tf - Terraform Provider Configuration
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHAT IS A PROVIDER?
# ───────────────────
# A provider is a plugin that lets Terraform talk to a cloud platform.
#   - aws provider → talks to AWS
#   - google provider → talks to GCP
#   - azurerm provider → talks to Azure
#   - kubernetes provider → talks to Kubernetes
#
# You can have MULTIPLE providers in one Terraform configuration.
# We'll add kubernetes provider later when we deploy to EKS.
#
# ═══════════════════════════════════════════════════════════════════════════════

terraform {
  # ─────────────────────────────────────────────────────────────────────────────
  # REQUIRED TERRAFORM VERSION
  # ─────────────────────────────────────────────────────────────────────────────
  # This ensures everyone uses a compatible Terraform version
  # ─────────────────────────────────────────────────────────────────────────────
  required_version = ">= 1.0.0"
  
  # ─────────────────────────────────────────────────────────────────────────────
  # REQUIRED PROVIDERS
  # ─────────────────────────────────────────────────────────────────────────────
  # This tells Terraform which provider plugins to download
  # ─────────────────────────────────────────────────────────────────────────────
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"    # Use version 5.x (latest stable)
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# AWS PROVIDER CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────────
# This configures how Terraform connects to AWS
# ─────────────────────────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region
  
  # ─────────────────────────────────────────────────────────────────────────────
  # DEFAULT TAGS
  # ─────────────────────────────────────────────────────────────────────────────
  # These tags are automatically added to EVERY resource Terraform creates.
  # Super useful for:
  #   - Cost tracking (filter by Environment tag)
  #   - Identifying resources (filter by Project tag)
  #   - Compliance (who created this?)
  # ─────────────────────────────────────────────────────────────────────────────
  default_tags {
    tags = {
      Project     = "modena"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# KUBERNETES PROVIDER CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────────
# Authenticates to EKS cluster for creating K8s resources (service accounts, etc.)

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# HELM PROVIDER CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────────
# Package manager for Kubernetes - installs Helm charts (like ALB controller)

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}