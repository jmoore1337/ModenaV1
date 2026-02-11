# ═══════════════════════════════════════════════════════════════════════════════
# RDS MODULE - OUTPUTS
# ═══════════════════════════════════════════════════════════════════════════════
# These outputs are EXPOSED back to the caller (environments/dev/main.tf)
# 
# The application needs these values to connect to the database:
#   - Endpoint (hostname)
#   - Port
#   - Database name
#   - Username
#
# PASSWORD IS NOT OUTPUT! It's sensitive and should come from Secrets Manager.
# ═══════════════════════════════════════════════════════════════════════════════

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_endpoint" {
  description = "The connection endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
  # Format: modena-dev-db.abc123xyz.us-east-1.rds.amazonaws.com:5432
  # This is what your app uses to connect!
}

output "db_host" {
  description = "The database hostname (without port)"
  value       = aws_db_instance.main.address
  # Format: modena-dev-db.abc123xyz.us-east-1.rds.amazonaws.com
}

output "db_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
  # Default: 5432
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
  # The database INSIDE PostgreSQL: "modena"
}

output "db_username" {
  description = "The master username"
  value       = aws_db_instance.main.username
  # "modena_admin"
}

output "db_security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
  # Other modules might need this to allow connections to RDS
}

# ─────────────────────────────────────────────────────────────────────────────────
# CONNECTION STRING (for convenience)
# ─────────────────────────────────────────────────────────────────────────────────
# WARNING: Does NOT include password - add that from Secrets Manager!

output "db_connection_string" {
  description = "PostgreSQL connection string (add password manually)"
  value       = "postgresql://${aws_db_instance.main.username}:PASSWORD@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  # Replace PASSWORD with actual password from Secrets Manager
  # Your FastAPI app will use this to connect
}