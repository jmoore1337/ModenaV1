# ═══════════════════════════════════════════════════════════════════════════════
# AWS LOAD BALANCER CONTROLLER MODULE - iam.tf
# ═══════════════════════════════════════════════════════════════════════════════
# Creates:
#   1. IAM policy - permissions for ALB controller
#   2. IAM role - with OIDC federated principal (NOT EC2 service)
#   3. IRSA service account - links pod to IAM role
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# IAM POLICY: What can the ALB controller do?
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: When the pod assumes the role, it needs specific AWS permissions
#      to create/modify ALBs and security groups
#      This policy defines those permissions

resource "aws_iam_role_policy" "alb_controller" {
  name = "${var.project_name}-${var.environment}-alb-controller-policy"
  role = aws_iam_role.alb_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ──────────────────────────────────────────────────────────────────────────
      # ELASTIC LOAD BALANCING (ELBv2) - Create/modify ALBs
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "ALBManagement"
        Effect = "Allow"
        Action = [
          "elbv2:CreateLoadBalancer",           # Create new ALB when Ingress created
          "elbv2:DeleteLoadBalancer",           # Delete ALB when Ingress deleted
          "elbv2:DescribeLoadBalancers",        # Check if ALB already exists
          "elbv2:DescribeLoadBalancerAttributes",
          "elbv2:ModifyLoadBalancerAttributes",  # Modify ALB settings
          "elbv2:CreateListener",                # Create listener (port 80, 443)
          "elbv2:DeleteListener",
          "elbv2:DescribeListeners",
          "elbv2:DescribeListenerCertificates",
          "elbv2:ModifyListener",
          "elbv2:CreateTargetGroup",            # Create target group (pod endpoints)
          "elbv2:DeleteTargetGroup",
          "elbv2:DescribeTargetGroups",
          "elbv2:ModifyTargetGroup",
          "elbv2:ModifyTargetGroupAttributes",
          "elbv2:RegisterTargets",              # Add pods as targets
          "elbv2:DeregisterTargets",            # Remove pods as targets
          "elbv2:DescribeTargetHealth",         # Check pod health
          "elbv2:DescribeTargetGroupAttributes",
          "elbv2:CreateRule",                   # Create routing rules (path-based)
          "elbv2:DeleteRule",
          "elbv2:DescribeRules",
          "elbv2:ModifyRule"
        ]
        Resource = "*"
        # WHY "*"? ALBs don't exist yet when Ingress is created
        #         Controller can't know the ARN in advance
        #         In prod, limit to specific ALB ARN patterns
      },

      # ──────────────────────────────────────────────────────────────────────────
      # EC2 - Describe VPCs, Subnets, Security Groups
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",        # Find SG for ALB
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeVpcs",                  # Find VPC for ALB
          "ec2:DescribeSubnets",               # Find subnets for ALB (needs 2+ AZs)
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetSecurityGroupsForVpc"
        ]
        Resource = "*"
        # WHY "*"? These are read-only describe operations
        #         No modification, just gathering info about VPC/subnets
      },

      # ──────────────────────────────────────────────────────────────────────────
      # EC2 - Modify Security Groups
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",  # Allow traffic to pod SGs
          "ec2:RevokeSecurityGroupIngress",     # Revoke rules when cleaned up
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
        # WHY? ALB needs to route traffic to pods
        #      Pod security group must allow ingress from ALB
        #      Controller modifies pod SG rules automatically
      },

      # ──────────────────────────────────────────────────────────────────────────
      # EC2 - Create/Delete Security Groups
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "SecurityGroupCreation"
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",           # Create SG for ALB itself
          "ec2:DeleteSecurityGroup",
          "ec2:CreateTags",                     # Tag resources for tracking
          "ec2:DeleteTags"
        ]
        Resource = "*"
        # WHY? Controller creates SG for ALB in the VPC
        #      Tags it with controller name + cluster info
      },

      # ──────────────────────────────────────────────────────────────────────────
      # ELASTIC IPS - For ALB
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "ElasticIPManagement"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",                # Assign elastic IP to ALB
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
        # WHY? Public ALBs need elastic IPs
        #      Ensures stable IP even if ALB restarts
      },

      # ──────────────────────────────────────────────────────────────────────────
      # CLOUDFORMATION TAGS - Track ALB creation
      # ──────────────────────────────────────────────────────────────────────────
      {
        Sid    = "ServiceLinkedRoleManagement"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:ModifyNetworkInterfaceAttribute"
        ]
        Resource = "*"
        # WHY? ALB needs to attach/detach ENIs to subnets
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────────
# IAM ROLE: Who can assume this role? (OIDC Federated Principal)
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: The role defines WHO can use those permissions
#      Unlike Jenkins (EC2 service), ALB controller is a POD
#      Pods use JWT tokens signed by EKS OIDC provider
#      AWS verifies JWT signature before granting credentials

resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-${var.environment}-alb-controller-role"

  # ──────────────────────────────────────────────────────────────────────────
  # assume_role_policy = "WHO can assume this role?"
  # ──────────────────────────────────────────────────────────────────────────
  # This is the CRITICAL DIFFERENCE from Jenkins
  #
  # JENKINS: Principal = { Service = "ec2.amazonaws.com" }
  #          → "The EC2 service can assume this role"
  #
  # ALB CONTROLLER: Principal = { Federated = var.oidc_provider_arn }
  #                 → "Only JWTs signed by THIS OIDC provider can assume this role"
  #
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        
        # ──────────────────────────────────────────────────────────────────
        # Principal: OIDC Provider (NOT EC2 service!)
        # ──────────────────────────────────────────────────────────────────
        Principal = {
          Federated = var.oidc_provider_arn
          # Example value:
          # arn:aws:iam::730335375020:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC123DEF456789
        }

        # ──────────────────────────────────────────────────────────────────
        # Condition: JWT claims must match these values
        # ──────────────────────────────────────────────────────────────────
        # WHY conditions?
        # Without conditions, ANY pod in the cluster could assume this role!
        # Conditions restrict it to ONLY the ALB controller service account
        #
        Condition = {
          StringEquals = {
            # Extract the OIDC provider URL from the ARN
            # Example: arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABC123
            # Extract: oidc.eks.us-east-1.amazonaws.com/id/ABC123:aud
            "${replace(var.oidc_provider_arn, "/^.*provider\\//", "")}:aud" = "sts.amazonaws.com"
            # WHY aud = sts.amazonaws.com?
            # JWT "audience" claim must be STS
            # Prevents the token from being used for other services
            # 
            # Example full claim: oidc.eks.us-east-1.amazonaws.com/id/ABC123:aud = sts.amazonaws.com

            "${replace(var.oidc_provider_arn, "/^.*provider\\//", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            # WHY sub = system:serviceaccount:kube-system:aws-load-balancer-controller?
            # JWT "subject" claim must be THIS specific service account
            # Prevents OTHER service accounts from using the token
            # Only the ALB controller service account can assume this role
            # 
            # Example full claim: oidc.eks.us-east-1.amazonaws.com/id/ABC123:sub = system:serviceaccount:kube-system:aws-load-balancer-controller
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-controller-role"
    Project     = var.project_name
    Environment = var.environment
    Component   = "networking"
  }
}


# ─────────────────────────────────────────────────────────────────────────────────
# PART 3: KUBERNETES SERVICE ACCOUNT (IRSA - IAM Roles for Service Accounts)
# ─────────────────────────────────────────────────────────────────────────────────
# WHY: Kubernetes service account is just a K8s object
#      We need to LINK it to the AWS IAM role so the pod gets credentials
#      This annotation does the linking: eks.amazonaws.com/role-arn = <role-arn>

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    # ──────────────────────────────────────────────────────────────────────
    # Annotation: Link this K8s service account to AWS IAM role
    # ──────────────────────────────────────────────────────────────────────
    # When Kubernetes kubelet injects the JWT token into the pod:
    # kubelet sees this annotation and adds:
    #   AWS_ROLE_ARN = arn:aws:iam::ACCOUNT:role/modena-dev-alb-controller-role
    #   AWS_WEB_IDENTITY_TOKEN_FILE = /var/run/secrets/eks.amazonaws.com/serviceaccount/token
    # Then the AWS SDK reads these env vars and exchanges JWT for credentials
    #
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
      # Example: arn:aws:iam::730335375020:role/modena-dev-alb-controller-role
    }

    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/version"    = "2.6.0"
      "app.kubernetes.io/part-of"    = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [
    aws_iam_role.alb_controller
  ]
  # WHY depends_on?
  # Terraform must create the IAM role BEFORE this service account
  # (annotation references the role ARN)
}

# ─────────────────────────────────────────────────────────────────────────────────
# What happens when the pod starts:
# ─────────────────────────────────────────────────────────────────────────────────
#
# 1. Helm release deploys: aws-load-balancer-controller Deployment
#    (we'll add this in main.tf)
#
# 2. Deployment creates pod with:
#    serviceAccountName: aws-load-balancer-controller (references this service account)
#
# 3. Kubernetes kubelet starts the pod and:
#    - Reads the service account annotation
#    - Generates a JWT token (signed by EKS OIDC provider)
#    - Mounts it at: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
#    - Injects env vars:
#      AWS_ROLE_ARN=arn:aws:iam::730335375020:role/modena-dev-alb-controller-role
#      AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
#
# 4. Pod code (AWS SDK) reads env vars and calls STS:
#    sts:AssumeRoleWithWebIdentity(
#      token=JWT,
#      role_arn=AWS_ROLE_ARN
#    )
#
# 5. AWS verifies JWT signature (from OIDC provider)
#    + checks conditions (aud + sub)
#    + returns temporary credentials
#
# 6. Pod uses credentials to:
#    - Create ALB (when Ingress is created)
#    - Modify security groups
#    - Register pods as ALB targets