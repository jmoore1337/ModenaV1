output "rds_secret_arn" {
  description = "ARN of the RDS password secret (for reference/audit)"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "rds_secret_name" {
  description = "Name of the RDS password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.rds_password.name
}

output "rds_password" {
  description = "RDS master password (passed to RDS module)"
  value       = random_password.rds_password.result
  sensitive   = true
}

output "rds_username" {
  description = "RDS master username"
  value       = var.db_username
  sensitive   = true
}