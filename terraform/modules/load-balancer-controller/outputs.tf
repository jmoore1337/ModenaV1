# ═══════════════════════════════════════════════════════════════════════════════
# AWS LOAD BALANCER CONTROLLER MODULE - outputs.tf
# ═══════════════════════════════════════════════════════════════════════════════
# Exports:
#   1. IAM role ARN (for reference by other modules)
#   2. Service account name (for debugging)
#   3. Helm release status (for verification)
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# OUTPUT 1: IAM Role ARN
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Other modules might need the role ARN
#      Example: If a pod needs to assume the same role (future)
#      Or for documentation/debugging

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for ALB controller"
  value       = aws_iam_role.alb_controller.arn
  
  # Example output:
  # arn:aws:iam::730335375020:role/modena-dev-alb-controller-role
}

# ─────────────────────────────────────────────────────────────────────────────────
# OUTPUT 2: IAM Role Name
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Sometimes you need just the role name (not full ARN)
#      For CLI commands, debugging, documentation

output "alb_controller_role_name" {
  description = "Name of the IAM role for ALB controller"
  value       = aws_iam_role.alb_controller.name
  
  # Example output:
  # modena-dev-alb-controller-role
}

# ─────────────────────────────────────────────────────────────────────────────────
# OUTPUT 3: Service Account Name
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Useful for debugging kubectl commands
#      "kubectl describe sa SERVICE_ACCOUNT_NAME -n kube-system"

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account_v1.alb_controller.metadata[0].name
  
  # Example output:
  # aws-load-balancer-controller
}

# ─────────────────────────────────────────────────────────────────────────────────
# OUTPUT 4: Service Account Namespace
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Useful for kubectl commands
#      Must include -n (namespace) f