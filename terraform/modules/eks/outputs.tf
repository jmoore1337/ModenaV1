# ═══════════════════════════════════════════════════════════════════════════════
# EKS MODULE - OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════
# Values exposed to the caller and needed for:
#   - kubectl configuration
#   - Jenkins deployment
#   - Other modules that interact with EKS
# ═══════════════════════════════════════════════════════════════════════════════

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
  # Used by: kubectl, Jenkins, Helm, any K8s tooling
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
  # This is the URL kubectl connects to
  # Format: https://XXXXX.gr7.us-east-1.eks.amazonaws.com
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster auth"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  # Used by kubectl to verify cluster identity
}

output "node_group_id" {
  description = "EKS node group ID (AL2023)"
  value       = aws_eks_node_group.al2023.id
}

output "node_group_arn" {
  description = "EKS node group ARN (AL2023)"
  value       = aws_eks_node_group.al2023.arn
}

output "node_group_status" {
  description = "EKS node group status (AL2023)"
  value       = aws_eks_node_group.al2023.status
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for pod IAM roles"
  value       = aws_iam_openid_connect_provider.eks.arn
  # Used to create IAM roles that pods can assume
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = aws_iam_openid_connect_provider.eks.url
}

# ─────────────────────────────────────────────────────────────────────────────────
# KUBECTL CONFIGURATION COMMAND
# ─────────────────────────────────────────────────────────────────────────────────
# Helpful output - tells you exactly how to configure kubectl

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${aws_eks_cluster.main.name}"
  # Run this after apply to connect kubectl to your cluster!
}