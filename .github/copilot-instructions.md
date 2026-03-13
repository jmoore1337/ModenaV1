# Copilot Instructions for MODENA Infrastructure

## Architecture Overview

**MODENA** is a multi-environment cloud infrastructure for deploying containerized applications to AWS EKS. The project uses **Terraform modules** to manage infrastructure as code across dev, stage, and prod environments.

### Core Stack
- **Compute**: EKS (Kubernetes 1.32) with AL2023 nodes in private subnets
- **Networking**: VPC with public/private subnets, NAT gateways (dev disables NAT to save $)
- **Container Registry**: ECR with image scanning and lifecycle policies
- **Database**: RDS PostgreSQL (modena_admin user)
- **Secrets**: AWS Secrets Manager + KMS encryption for RDS passwords
- **CI/CD**: Jenkins on EC2 t3.small (public subnet)
- **Ingress**: AWS Load Balancer Controller (ALB) with IRSA pod roles
- **State Backend**: S3 + DynamoDB (requires `-lock=false` for `devops-jenkins-user`)

### AWS Account Context
- Account ID: `730335375020`
- Region: `us-east-1`
- CLI Profile: `top-admin` (must set `$env:AWS_PROFILE = "top-admin"` in PowerShell)
- OIDC Provider: `arn:aws:iam::730335375020:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/7B4C87620E3BF62997B851A805A49154`

---

## Terraform Module Structure

### Critical Dependency Chain
```
vpc ─────────────────┐
                     ├──> eks ─┐
iam ───────────────> ekс       ├──> load-balancer-controller
                               │
secrets ────────────────────────┘

ecr (independent)
rds (independent)
jenkins (independent)
```

All modules are in `terraform/modules/`. Each environment (`dev`, `stage`, `prod`) in `terraform/environments/{env}/` instantiates modules via `main.tf` with environment-specific values from `variables.tf` and `terraform.tfvars`.

### Module Conventions
- **Naming**: `local.name_prefix = "${var.project_name}-${var.environment}"` → `"modena-dev"`
- **Tagging**: All resources tagged with `{Project: modena, Environment: dev/stage/prod, ManagedBy: terraform}`
- **Outputs**: Named clearly, exported to parent `environments/{env}/outputs.tf` for terraform outputs or further module use
- **Variables**: Use `~> X.Y` constraints (e.g., `~> 5.0` allows 5.x but not 6.x) for flexibility + stability
- **Defaults**: Reasonable for dev (small instances, NAT disabled), override for prod via tfvars

### Key Modules Details

**EKS Module** ([terraform/modules/eks/](terraform/modules/eks/))
- Creates cluster + node group + OIDC provider (for pod IAM roles)
- Node group: AL2023 AMI, default t3.medium, min/max autoscaling configured
- Private subnet deployment (nodes NOT directly internet-accessible)
- Cluster API endpoint: public access enabled (dev), disable for prod + bastion
- OIDC provider: enables IRSA (pods assume IAM roles without storing credentials)

**IAM Module** ([terraform/modules/iam/](terraform/modules/iam/))
- Splits roles by least privilege: cluster role vs. node role
- EKS node role: gets EKS CNI, ECR read-only, EC2 describe permissions + instance profile
- Jenkins user: ECR push, Secrets Manager read, EKS describe policies
- Output: `eks_node_role_arn` used by EKS module

**Load Balancer Controller Module** ([terraform/modules/load-balancer-controller/](terraform/modules/load-balancer-controller/))
- Helm release: chart v3.1.0 from `aws.github.io/eks-charts`
- Kubernetes service account with IRSA annotation: `eks.amazonaws.com/role-arn`
- IAM role with inline policy: ELBv2, EC2 describe, tag-on-resource permissions
- Deployment: 2 replicas in `kube-system` namespace
- Purpose: Watches Ingress resources and provisions ALBs

---

## Provider Configuration (Critical Fix)

### Correct Provider Versions (as of latest commit)
```hcl
terraform {
  required_providers {
    aws        = "~> 5.0"          # hashicorp/aws v5.100.0
    kubernetes = "~> 2.35"         # hashicorp/kubernetes v2.38.0  
    helm       = "~> 2.17"         # hashicorp/helm v2.17.0
  }
}
```

**Why these versions matter:**
- **Kubernetes v3.0.x** (old lock file): No exec-based auth support, broke modules
- **Helm v3.1.x** (old lock file): No `kubernetes {}` nested block, no `set {}` blocks → broke all Helm releases
- **Downgrade to v2.x**: Restores exec-based auth (calls `aws eks get-token`), reintroduces ansible/configuration blocks

### Authentication Pattern
```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    # same exec config as above
  }
}
```

**No long-lived credentials stored.** Tokens are short-lived and retrieved on-demand via AWS CLI.

---

## Deployment Workflow

### Setup (One-time)
```powershell
cd terraform/environments/dev
$env:AWS_PROFILE = "top-admin"        # MUST set this in PowerShell

# Get/update providers + modules
terraform init -upgrade               # Forces re-download of provider versions from lock file

# Validate configuration syntax
terraform validate
```

### Deploy
```powershell
# Preview changes (DRY-RUN)
terraform plan -lock=false            # -lock=false required (Jenkins user lacks DynamoDB perms)

# Apply changes
terraform apply -auto-approve -lock=false

# Show outputs
terraform output
```

### Kubernetes Access (After EKS deployment)
```powershell
# Configure kubeconfig
aws eks update-kubeconfig --region us-east-1 --name modena-dev-eks

# Verify cluster access
kubectl get nodes
kubectl get pods -n kube-system

# Check ALB controller (Step 3 completion)
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

## Common Patterns & Conventions

### 1. Module Cross-References
**Main file** instantiates modules and passes outputs to dependents:
```hcl
module "vpc" { ... }
module "eks" {
  vpc_id            = module.vpc.vpc_id              # ← output from vpc module
  subnet_ids        = module.vpc.private_subnet_ids
  eks_node_role_arn = module.iam.eks_node_role_arn   # ← output from iam module
}
```

**Output files** in each module export values needed by main:
```hcl
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}
```

### 2. IRSA Pattern (Pod IAM Roles)
Pods assume IAM roles via Kubernetes service accounts:

1. **Create service account** with annotation:
   ```hcl
   resource "kubernetes_service_account_v1" "alb_controller" {
     metadata {
       annotations = {
         "eks.amazonaws.com/role-arn" = "arn:aws:iam::ACCOUNT:role/modena-dev-alb-controller-role"
       }
     }
   }
   ```

2. **Create IAM role** with OIDC trust:
   ```hcl
   assume_role_policy = jsonencode({
     Principal = {
       Federated = "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/THUMBPRINT"
     }
     Condition = {
       StringEquals = {
         "oidc.eks.us-east-1.amazonaws.com/id/THUMBPRINT:sub" = "system:serviceaccount:kube-system:alb-controller"
       }
     }
   })
   ```

3. **Pod uses role** automatically (kube2iam sidecar not needed in modern EKS).

### 3. Naming & Tagging
- Resource name: `"${local.name_prefix}-<resource-type>"` → `"modena-dev-eks"`
- Tags applied via `merge(var.tags, {...})` to ensure consistency
- DRY: Don't repeat project/env in tags; use `local.name_prefix` instead

### 4. Instance Type Cheat Sheet
- `t3.small` (2vCPU, 2GB) ~$15/mo: **TOO SMALL** for Kubernetes
- `t3.medium` (2vCPU, 4GB) ~$30/mo: **Dev choice** ✓
- `t3.large` (2vCPU, 8GB) ~$60/mo: Stage
- `t3.xlarge` (4vCPU, 16GB) ~$120/mo: Production

Why? Kubernetes system pods (coredns, kube-proxy) consume ~1GB on every node.

---

## Debugging & Validation

### Terraform Errors
- **Provider version mismatch**: Check `.terraform.lock.hcl` vs. `required_providers`. Run `terraform init -upgrade` if stale.
- **Kubernetes provider connection fails**: Verify `$env:AWS_PROFILE = "top-admin"` is set; missing OIDC or cluster not ready?
- **Helm release timeout**: Check Helm pod logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

### Kubernetes Diagnostics
```powershell
# Cluster access
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# Service account IRSA
kubectl describe sa -n kube-system aws-load-balancer-controller
kubectl describe role -n kube-system <role-name>

# Helm release status
helm list -n kube-system
helm get values aws-load-balancer-controller -n kube-system
```

### Git Workflow
- Commit only Terraform code + lock files, NOT `.terraform/` directory (in `.gitignore`)
- Disney references appear ONLY in `docs/` and `architecture-diagrams/` (interview prep), NOT in infrastructure code
- Tag releases after major milestones: `git tag -a v0.3-alb-controller -m "Deploy ALB controller"`

---

## Project Roadmap (Steps 3-26)

**Step 3 (COMPLETED)**: ALB controller deployed, pods accessible via Ingress
- ✅ Kubernetes provider fixed (v2.35)
- ✅ Helm provider fixed (v2.17)
- ✅ ALB controller Helm release deployed
- ✅ 2/2 pods running in kube-system

**Step 4 (NEXT)**: Create Ingress YAML to expose services
- Create `k8s/base/ingress.yaml` with ALBv2 ingress resources
- Annotate with `alb.ingress.kubernetes.io/load-balancer-type: application`

**Step 5**: CloudWatch Container Insights
- Deploy Fluent Bit DaemonSet to ship logs

**Step 6+**: Full CICD pipeline, monitoring, security scanning

---

## File Reference Guide

| File | Purpose |
|------|---------|
| [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf) | Module orchestration for dev |
| [terraform/environments/dev/providers.tf](terraform/environments/dev/providers.tf) | Provider config: AWS, Kubernetes, Helm (CRITICAL: v2.35/v2.17) |
| [terraform/modules/eks/main.tf](terraform/modules/eks/main.tf) | EKS cluster + node group + OIDC |
| [terraform/modules/load-balancer-controller/iam.tf](terraform/modules/load-balancer-controller/iam.tf) | IRSA role + service account |
| [terraform/modules/load-balancer-controller/main.tf](terraform/modules/load-balancer-controller/main.tf) | Helm release config |
| [terraform/.terraform.lock.hcl](terraform/environments/dev/.terraform.lock.hcl) | Locked provider versions (pinned to v2.38.0 / v2.17.0) |
| [k8s/base/](k8s/base/) | Kubernetes manifests (kustomization base) |
| [Jenkins/Jenkinsfile](Jenkins/Jenkinsfile) | CI/CD pipeline |

---

## Tips for Working with This Codebase

1. **Always use `-lock=false`** in dev environment: Jenkins user lacks DynamoDB permissions
2. **Pin provider versions explicitly** in `required_providers`: Don't let auto-upgrades break your Helm syntax
3. **Test module changes in dev first**: Validate provider changes before applying to prod
4. **Check `.gitignore`** before committing: Docker config, private keys, tfstate files should never reach GitHub
5. **Use `merge(var.tags, {...})`** for all resource tags: Ensures consistent tagging pattern
6. **Document "WHY"** in Terraform comments: This codebase has extensive inline comments for learning purposes
7. **Reference OIDC provider ARN** when creating pod IAM roles: Don't hardcode; use `module.eks.oidc_provider_arn`

---

## Questions to Ask When Adding Features

- **Is this infrastructure or application code?** (Terraform vs. k8s manifests)
- **Which modules depend on this change?** (Check module interdependencies)
- **What's the least privilege IAM policy?** (Don't use `*` actions; be specific)
- **Have I tested in dev before prod?** (Always dev → stage → prod)
- **Is this tagged + named consistently?** (Use `local.name_prefix` pattern)
