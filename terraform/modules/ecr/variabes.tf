# ═══════════════════════════════════════════════════════════════════════════════
# variables.tf - ECR Module Inputs
# ═══════════════════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "modena"
}

variable "image_retention_count" {
  description = "Number of images to keep (older ones get deleted)"
  type        = number
  default     = 10
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities when pushed"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}