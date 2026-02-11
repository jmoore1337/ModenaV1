# ═══════════════════════════════════════════════════════════════════════════════
# RDS MODULE - VARIABLES (Input Parameters)
# ═══════════════════════════════════════════════════════════════════════════════
# These variables are RECEIVED from environments/dev/main.tf when it calls:
#   module "rds" {
#     environment    = var.environment      ← Passes "dev"
#     vpc_id         = module.vpc.vpc_id    ← Passes VPC ID from VPC module output
#     subnet_ids     = module.vpc.private_subnet_ids  ← Where RDS lives
#   }
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES (No defaults - caller MUST provide these)
# ─────────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name (dev, stage, prod) - used in naming and tags"
  type        = string
  # No default = REQUIRED. Module won't work without this.
  # WHY required? Every resource needs to know its environment for:
  #   - Naming: modena-dev-db vs modena-prod-db
  #   - Tagging: Environment = "dev" for cost tracking
  #   - Config: Dev might skip Multi-AZ, prod needs it
}

variable "vpc_id" {
  description = "VPC ID where RDS will be created - needed for security group"
  type        = string
  # WHY required? Security groups are VPC-specific.
  # We get this from: module.vpc.vpc_id (VPC module output)
}

variable "subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group"
  type        = list(string)
  # WHY a list? RDS subnet group requires subnets in multiple AZs.
  # Even if we don't use Multi-AZ now, AWS requires 2+ subnets.
  # We get this from: module.vpc.private_subnet_ids
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to RDS (e.g., EKS nodes)"
  type        = list(string)
  default     = []
  # WHY? Only specific resources should reach the database.
  # Later: EKS node security group will be added here.
  # Empty for now - we'll update when EKS module is built.
}

# ─────────────────────────────────────────────────────────────────────────────────
# OPTIONAL VARIABLES (Have defaults - can be overridden)
# ─────────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "modena"
}

variable "db_name" {
  description = "Name of the database to create inside PostgreSQL"
  type        = string
  default     = "modena"
  # This is the DATABASE name, not the instance name.
  # Instance name: modena-dev-db
  # Database name inside: modena
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "modena_admin"
  # WHY not 'admin' or 'root'? Those are common attack targets.
  # Use something specific to your app.
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true  # ← Hides from terraform plan/apply output!
  # ═══════════════════════════════════════════════════════════════════
  # SECURITY NOTE: In production, NEVER put passwords in variables.tf!
  # Options:
  #   1. terraform apply -var="db_password=secret123"
  #   2. TF_VAR_db_password environment variable
  #   3. Secrets Manager (we'll add this in Phase 2.6)
  # For dev/learning, we'll pass it via command line.
  # ═══════════════════════════════════════════════════════════════════
}

variable "instance_class" {
  description = "RDS instance type - determines CPU/RAM"
  type        = string
  default     = "db.t3.micro"
  # ─────────────────────────────────────────────────────────────────
  # INSTANCE CLASS CHEAT SHEET:
  # ─────────────────────────────────────────────────────────────────
  # db.t3.micro  = 2 vCPU, 1GB RAM   - $0.017/hr (~$12/mo) - DEV
  # db.t3.small  = 2 vCPU, 2GB RAM   - $0.034/hr (~$25/mo) - STAGE
  # db.t3.medium = 2 vCPU, 4GB RAM   - $0.068/hr (~$50/mo) - Small PROD
  # db.r5.large  = 2 vCPU, 16GB RAM  - $0.24/hr (~$175/mo) - PROD
  # ─────────────────────────────────────────────────────────────────
  # From your Dsny interview transcript, you mentioned:
  # "switching over from i3.large or i5" for OpenSearch
  # Same concept - instance class determines performance!
  # ─────────────────────────────────────────────────────────────────
}

variable "allocated_storage" {
  description = "Storage size in GB"
  type        = number
  default     = 20
  # WHY 20? It's the minimum for gp3 storage.
  # Modena scan results are small - 20GB is plenty for dev.
  # Prod might need 100GB+ depending on scan volume.
}

variable "engine_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
  # WHY 15? It's stable and has good features.
  # Always specify a version - don't let AWS pick!
  # Unspecified version = surprise upgrades = broken app
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
  # ─────────────────────────────────────────────────────────────────
  # MULTI-AZ EXPLAINED:
  # ─────────────────────────────────────────────────────────────────
  # false = Single instance (cheaper, fine for dev)
  # true  = Standby replica in another AZ (auto-failover)
  #
  # Cost impact: Multi-AZ roughly DOUBLES the cost!
  # Dev:  false (save money)
  # Prod: true  (high availability)
  #
  # This is like the Dsny canary deployment pattern you worked on -
  # having redundancy for critical systems.
  # ─────────────────────────────────────────────────────────────────
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying (true for dev, false for prod)"
  type        = bool
  default     = true
  # WHY true for dev? When you terraform destroy, you don't want to wait
  # for a snapshot. For prod, set false to keep a backup.
}

variable "deletion_protection" {
  description = "Prevent accidental deletion"
  type        = bool
  default     = false
  # Dev: false (easy cleanup)
  # Prod: true (prevent accidents!)
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 7
  # 0 = no backups (not recommended)
  # 7 = keep 7 days of point-in-time recovery
  # 35 = max retention (for prod/compliance)
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}