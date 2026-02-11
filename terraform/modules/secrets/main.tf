# ═══════════════════════════════════════════════════════════════════════════════
# Secrets Module — KMS Key + Secrets Manager + Access Policies
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# SECTION 1: GENERATE RANDOM PASSWORD
# ─────────────────────────────────────────────────────────────────────────────────
# Create a random password for RDS. Never hardcode passwords!

resource "random_password" "rds_password" {
  length  = var.db_password_length
  special = true
}

# ─────────────────────────────────────────────────────────────────────────────────
# SECTION 2: KMS KEY FOR ENCRYPTION
# ─────────────────────────────────────────────────────────────────────────────────
# Secrets Manager uses this key to encrypt the password at rest

resource "aws_kms_key" "secrets" {
  description             = "KMS key for encrypting RDS password in ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
    Component   = "secrets"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.environment}-rds-password-key"
  target_key_id = aws_kms_key.secrets.key_id
}

# ─────────────────────────────────────────────────────────────────────────────────
# SECTION 3: SECRETS MANAGER SECRET
# ─────────────────────────────────────────────────────────────────────────────────
# Store RDS credentials (username + password) encrypted

resource "aws_secretsmanager_secret" "rds_password" {
  name_prefix             = "${var.environment}-rds-password-"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
    Component   = "database"
  }
}

# The actual secret value (username + password as JSON)
resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.rds_password.result
    engine   = "postgres"
    host     = "rds-endpoint-will-be-set-by-rds-module"
    port     = 5432
    dbname   = "modena"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# SECTION 4: IAM POLICY - GRANT EKS NODES ACCESS TO READ SECRET
# ─────────────────────────────────────────────────────────────────────────────────
# EKS nodes need permission to read the secret from Secrets Manager

resource "aws_iam_role_policy" "eks_node_read_secrets" {
  name = "${var.environment}-eks-node-read-secrets"
  role = data.aws_iam_role.eks_node_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_password.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# DATA SOURCE - LOOK UP THE EKS NODE ROLE BY ARN
# ─────────────────────────────────────────────────────────────────────────────────
# We receive the role ARN as input, but need the role ID to attach policy
# This data source looks up the role by its ARN

data "aws_iam_role" "eks_node_role" {
  name = var.eks_node_role_name
}