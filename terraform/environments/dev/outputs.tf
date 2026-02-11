# ═══════════════════════════════════════════════════════════════════════════════
# RDS OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.db_endpoint
}

output "rds_host" {
  description = "RDS hostname"
  value       = module.rds.db_host
}

output "rds_database_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "rds_connection_string" {
  description = "Connection string (add password from Secrets Manager)"
  value       = module.rds.db_connection_string
  sensitive   = true
}

# ═══════════════════════════════════════════════════════════════════════════════
# EKS OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_kubectl_command" {
  description = "Command to configure kubectl"
  value       = module.eks.kubectl_config_command
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEMPORARILY COMMENTED: Secrets & Jenkins outputs
# ═══════════════════════════════════════════════════════════════════════════════
# Will be re-enabled when IAM + Secrets modules are activated

# output "rds_secret_arn" {
#   description = "ARN of RDS password secret"
#   value       = module.secrets.rds_secret_arn
# }

# output "rds_username" {
#   description = "RDS master username"
#   value       = module.secrets.rds_username
#   sensitive   = true
# }

# output "jenkins_access_key_id" {
#   description = "Jenkins IAM user Access Key ID"
#   value       = module.iam.jenkins_access_key_id
#   sensitive   = true
# }

# output "jenkins_secret_access_key" {
#   description = "Jenkins IAM user Secret Access Key"
#   value       = module.iam.jenkins_secret_access_key
#   sensitive   = true
# }

