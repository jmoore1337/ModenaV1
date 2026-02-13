# ═══════════════════════════════════════════════════════════════════════════════
# IAM Module — Identity & Access Management
# ═══════════════════════════════════════════════════════════════════════════════
# Creates EKS Node Role and Jenkins IAM User with least-privilege permissions
# ═══════════════════════════════════════════════════════════════════════════════


# ─────────────────────────────────────────────────────────────────────────────────
# PART 1: EKS NODE ROLE
# ─────────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Component   = "eks"
  }
}

# Attach AWS-managed policies to the EKS node role
# These grant nodes permission to work with EKS, networking, and ECR

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create an instance profile to hold the EKS node role
# EC2 instances need an instance profile to assume the role
resource "aws_iam_instance_profile" "eks_node_instance_profile" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.eks_node_role.name
}

# ─────────────────────────────────────────────────────────────────────────────────
# PART 2: JENKINS IAM USER
# ─────────────────────────────────────────────────────────────────────────────────

# Create Jenkins IAM user for CI/CD pipeline
resource "aws_iam_user" "jenkins" {
  name = "devops-jenkins-user"
  
  tags = {
    Environment = var.environment
    Component   = "ci-cd"
  }
}

# Attach custom policies to Jenkins user
# Each policy grants ONLY what Jenkins needs (least privilege)

# Policy 1: ECR Push permissions
resource "aws_iam_user_policy" "jenkins_ecr_push" {
  name = "${var.environment}-jenkins-ecr-push"
  user = aws_iam_user.jenkins.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/modena-*"
      }
    ]
  })
}

# Create access keys for Jenkins user
# These credentials (Access Key ID + Secret) will be stored in Jenkins Credentials Manager
resource "aws_iam_access_key" "jenkins" {
  user = aws_iam_user.jenkins.name

  lifecycle {
    create_before_destroy = true
  }
}
