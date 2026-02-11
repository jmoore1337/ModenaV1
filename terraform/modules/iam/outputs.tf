# ═══════════════════════════════════════════════════════════════════════════════
# IAM Module — Outputs
# ═══════════════════════════════════════════════════════════════════════════════
# These outputs are used by:
#   1. terraform/environments/dev/main.tf (EKS module receives them)
#   2. terraform/environments/dev/outputs.tf (display to user)

output "eks_node_role_arn" {
  description = "ARN of the EKS node IAM role (used by EKS module)"
  value       = aws_iam_role.eks_node_role.arn
}

output "eks_node_instance_profile_name" {
  description = "Name of the instance profile for EKS nodes (used by EKS module)"
  value       = aws_iam_instance_profile.eks_node_instance_profile.name
}

output "jenkins_access_key_id" {
  description = "Jenkins IAM user Access Key ID (save to Jenkins Credentials Manager)"
  value       = aws_iam_access_key.jenkins.id
  sensitive   = true
}

output "jenkins_secret_access_key" {
  description = "Jenkins IAM user Secret Access Key (save to Jenkins Credentials Manager)"
  value       = aws_iam_access_key.jenkins.secret
  sensitive   = true
}

output "eks_node_role_name" {
  description = "Name of the EKS node IAM role (used by Secrets module and others)"
  value       = aws_iam_role.eks_node_role.name
}