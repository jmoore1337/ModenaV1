# ═══════════════════════════════════════════════════════════════════════════════
# main.tf - ECR Module Resources
# ═══════════════════════════════════════════════════════════════════════════════

locals {
  repositories = ["backend", "frontend"]
  
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# ECR REPOSITORIES
# ─────────────────────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "main" {
  for_each = toset(local.repositories)
  
  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = "IMMUTABLE"
  
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# LIFECYCLE POLICY - Auto-delete old images
# ─────────────────────────────────────────────────────────────────────────────────
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main
  
  repository = each.value.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only ${var.image_retention_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}