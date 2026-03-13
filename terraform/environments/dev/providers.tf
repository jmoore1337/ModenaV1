# ═══════════════════════════════════════════════════════════════════════════════
# providers.tf - Terraform Provider Configuration
# ═══════════════════════════════════════════════════════════════════════════════
#
# WHAT IS A PROVIDER?
# ───────────────────
# A provider is a plugin that lets Terraform talk to a cloud platform.
#   - aws provider → talks to AWS
#   - kubernetes provider → talks to Kubernetes API
#   - helm provider → installs Helm charts on Kubernetes
#
# ═══════════════════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# AWS PROVIDER
# ─────────────────────────────────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "modena"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# KUBERNETES PROVIDER
# ─────────────────────────────────────────────────────────────────────────────────
# Uses exec-based auth (calls `aws eks get-token`) to get a short-lived token.
# This is the recommended approach — no long-lived credentials stored anywhere.

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ─────────────────────────────────────────────────────────────────────────────────
# HELM PROVIDER
# ─────────────────────────────────────────────────────────────────────────────────
# Same auth as Kubernetes provider — exec-based, calls `aws eks get-token`.

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}