# ═══════════════════════════════════════════════════════════════════════════════
# outputs.tf - ECR Module Outputs
# ═══════════════════════════════════════════════════════════════════════════════

output "repository_urls" {
  description = "Map of repository names to URLs"
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository names to ARNs (for IAM policies)"
  value       = { for k, v in aws_ecr_repository.main : k => v.arn }
}

output "registry_id" {
  description = "The AWS account ID (registry ID)"
  value       = values(aws_ecr_repository.main)[0].registry_id
}