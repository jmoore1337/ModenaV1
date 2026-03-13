# ═══════════════════════════════════════════════════════════════════════════════
# AWS LOAD BALANCER CONTROLLER MODULE - main.tf
# ═══════════════════════════════════════════════════════════════════════════════

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = var.eks_cluster_name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.alb_controller.metadata[0].name
      }
      region       = data.aws_region.current.name
      vpcId        = var.vpc_id
      enableShield = false
      enableWaf    = false
    })
  ]

  depends_on = [
    kubernetes_service_account_v1.alb_controller
  ]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ═══════════════════════════════════════════════════════════════════════════
# AWS LOAD BALANCER CONTROLLER IAM POLICY (Kept for reference - defined in iam.tf)
# ═══════════════════════════════════════════════════════════════════════════
# WHY: The controller needs permissions to create ALBs, target groups, 
#      modify security groups. This policy defines EXACTLY what it can do.
#
# This follows the principle of least privilege - the controller has NO
# permissions except for load balancing operations.

# Note: The actual policy is in iam.tf as inline policy attached to the role
# This was previously here but moved to iam.tf for better organization

# Inline policy defined in iam.tf