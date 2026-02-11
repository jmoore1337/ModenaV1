# ═══════════════════════════════════════════════════════════════════════════════
# RDS MODULE - MAIN (Resource Definitions)
# ═══════════════════════════════════════════════════════════════════════════════
# This file CREATES the actual AWS resources using values from variables.tf
# 
# RESOURCES CREATED:
#   1. DB Subnet Group    - Tells RDS which subnets to use
#   2. Security Group     - Firewall rules (who can connect)
#   3. RDS Instance       - The actual PostgreSQL database
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────────────────────────
# Computed values used throughout this module

locals {
  # Consistent naming: modena-dev-xxx
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Merge default tags with any additional tags passed in
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ─────────────────────────────────────────────────────────────────────────────────
# DB SUBNET GROUP
# ─────────────────────────────────────────────────────────────────────────────────
# WHY? RDS needs to know which subnets it can use.
# We use PRIVATE subnets because database should NOT be internet-accessible!
#
# INTERVIEW TIP: "I place RDS in private subnets with a subnet group spanning
# multiple AZs. Even without Multi-AZ enabled, the subnet group must have
# subnets in 2+ AZs as an AWS requirement."

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group for ${local.name_prefix} RDS instance"
  subnet_ids  = var.subnet_ids  # ← Private subnets from VPC module
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP
# ─────────────────────────────────────────────────────────────────────────────────
# WHY? Controls WHO can connect to the database.
# Only allow connections from specific security groups (like EKS nodes).
#
# THIS IS THE SECURITY PATTERN YOU SAW AT CISCO WITH WIZ!
# Wiz flagged databases that were too permissive. This security group
# ensures ONLY authorized resources can connect.

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for ${local.name_prefix} RDS instance"
  vpc_id      = var.vpc_id  # ← From VPC module output
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP RULES (Separate resources for clarity)
# ─────────────────────────────────────────────────────────────────────────────────
# WHY separate rules? Easier to read, modify, and debug.
# Also allows dynamic rules based on allowed_security_group_ids.

# INGRESS: Allow PostgreSQL traffic (port 5432) from allowed security groups
resource "aws_security_group_rule" "rds_ingress" {
  count = length(var.allowed_security_group_ids) > 0 ? length(var.allowed_security_group_ids) : 0
  
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Allow PostgreSQL from authorized security groups"
}

# INGRESS: Allow from VPC CIDR (temporary for dev - remove in prod!)
# This allows any resource in the VPC to connect during development.
resource "aws_security_group_rule" "rds_ingress_vpc" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["10.0.0.0/16"]  # VPC CIDR
  description       = "Allow PostgreSQL from within VPC (dev only)"
}

# EGRESS: Allow all outbound (standard pattern)
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

# ─────────────────────────────────────────────────────────────────────────────────
# RDS INSTANCE
# ─────────────────────────────────────────────────────────────────────────────────
# THE ACTUAL DATABASE!
#
# COST ESTIMATE (db.t3.micro in us-east-1):
#   Instance:  ~$12/month
#   Storage:   ~$2/month (20GB gp3)
#   Total:     ~$14/month for dev
#
# INTERVIEW TIP: "I configure RDS with the minimum viable settings for dev -
# t3.micro, single-AZ, minimal storage. For prod, I'd enable Multi-AZ,
# increase instance class, and set deletion_protection = true."

resource "aws_db_instance" "main" {
  # ───────────────────────────────────────────────────────────────────
  # IDENTIFICATION
  # ───────────────────────────────────────────────────────────────────
  identifier = "${local.name_prefix}-db"  # AWS resource name: modena-dev-db
  db_name    = var.db_name                # Database inside: modena
  
  # ───────────────────────────────────────────────────────────────────
  # ENGINE CONFIGURATION
  # ───────────────────────────────────────────────────────────────────
  engine               = "postgres"
  engine_version       = var.engine_version   # "15"
  instance_class       = var.instance_class   # "db.t3.micro"
  parameter_group_name = "default.postgres15" # Use AWS default params
  
  # ───────────────────────────────────────────────────────────────────
  # STORAGE
  # ───────────────────────────────────────────────────────────────────
  allocated_storage     = var.allocated_storage  # 20 GB
  storage_type          = "gp3"                  # General Purpose SSD v3
  storage_encrypted     = true                   # ALWAYS encrypt at rest!
  # Note: gp3 is newer and cheaper than gp2 with better baseline performance
  
  # ───────────────────────────────────────────────────────────────────
  # CREDENTIALS
  # ───────────────────────────────────────────────────────────────────
  username = var.db_username  # "modena_admin"
  password = var.db_password  # Passed via -var or env var (NEVER hardcode!)
  
  # ───────────────────────────────────────────────────────────────────
  # NETWORK
  # ───────────────────────────────────────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # CRITICAL: Not internet-accessible!
  port                   = 5432   # PostgreSQL default port
  
  # ───────────────────────────────────────────────────────────────────
  # HIGH AVAILABILITY
  # ───────────────────────────────────────────────────────────────────
  multi_az = var.multi_az  # false for dev, true for prod
  # When true, AWS creates a standby replica in another AZ
  # Automatic failover if primary fails (typically < 60 seconds)
  
  # ───────────────────────────────────────────────────────────────────
  # BACKUP & RECOVERY
  # ───────────────────────────────────────────────────────────────────
  backup_retention_period = var.backup_retention_period  # 7 days
  backup_window           = "03:00-04:00"                # 3-4 AM UTC
  maintenance_window      = "Mon:04:00-Mon:05:00"        # Monday 4-5 AM UTC
  # WHY these times? Low-traffic window for your timezone.
  # Maintenance can cause brief interruptions.
  
  # ───────────────────────────────────────────────────────────────────
  # LIFECYCLE
  # ───────────────────────────────────────────────────────────────────
  deletion_protection       = var.deletion_protection   # false for dev
  skip_final_snapshot       = var.skip_final_snapshot   # true for dev
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-db-final-snapshot"
  # If skip_final_snapshot = false, creates a snapshot before deletion
  
  # ───────────────────────────────────────────────────────────────────
  # MONITORING
  # ───────────────────────────────────────────────────────────────────
  performance_insights_enabled = false  # Extra cost - enable for prod debugging
  # enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]  # Optional
  
  # ───────────────────────────────────────────────────────────────────
  # TAGS
  # ───────────────────────────────────────────────────────────────────
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}