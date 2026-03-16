# MODENA Migration to New AWS Account

**Purpose:** Step-by-step guide to replicate MODENA infrastructure in a new AWS account.

---

## Phase 1: Pre-Migration (Current Account)

### 1.1 Export Current State

```bash
cd terraform/environments/dev

# Save Terraform outputs for reference
terraform output > ../../docs/CURRENT-OUTPUTS.txt

# Document current deployment status
echo "=== EKS Cluster ===" >> ../../docs/CURRENT-STATE.txt
kubectl get nodes >> ../../docs/CURRENT-STATE.txt
kubectl get pods -n kube-system >> ../../docs/CURRENT-STATE.txt

# Export container image tags
aws ecr describe-repositories --region us-east-1 > ../../docs/ECR-REPOS.json
```

### 1.2 Verify Git is Current

```bash
cd ~/modena

# Ensure all code is committed
git status

# Tag the current deployment
git tag -a v0.3-pre-migration -m "State before account migration"
git push origin --tags
```

### 1.3 Document Current Configuration

**Save this file reference:**
- Current Account ID: `730335375020`
- Current Region: `us-east-1`
- Current VPC CIDR: `10.0.0.0/16`
- Current Environment Name: `dev`
- Current Project Name: `modena`

---

## Phase 2: New Account Setup

### 2.1 AWS Account Prerequisites

**In new AWS account (via Console):**

1. Create IAM user: `terraform-admin` (or similar)
   - Attach policy: `AdministratorAccess` (for testing) or least-privilege for prod
   - Generate Access Key ID + Secret Access Key

2. Store credentials in `~/.aws/credentials`:
   ```
   [new-admin]
   aws_access_key_id = AKIA...
   aws_secret_access_key = ...
   region = us-east-1
   ```

3. Test connectivity:
   ```bash
   export AWS_PROFILE=new-admin
   aws sts get-caller-identity
   # Should show new Account ID
   ```

### 2.2 Update MODENA Configuration

**File: `terraform/environments/dev/terraform.tfvars`**

```hcl
# Change ONLY these values:
aws_region     = "us-east-1"              # Keep same
aws_account_id = "XXXXXXXXXXXXX"          # ← NEW ACCOUNT ID
environment    = "dev"                    # Keep same
project_name   = "modena"                 # Keep same
vpc_cidr       = "10.0.0.0/16"           # Can adjust if needed
```

**No other changes needed** — all Terraform code uses variables.

### 2.3 Initialize Terraform in New Account

```bash
cd terraform/environments/dev

# Set new AWS profile
export AWS_PROFILE=new-admin

# Delete old lock file (specific to current account)
rm -f .terraform.lock.hcl

# Initialize with new account (creates fresh state backend)
terraform init

# Validate syntax
terraform validate
```

---

## Phase 3: Infrastructure Deployment

### 3.1 Deploy AWS Infrastructure

```bash
# Preview changes
terraform plan -lock=false

# Deploy (takes ~15-20 minutes)
terraform apply -auto-approve -lock=false

# Capture outputs
terraform output > ../../docs/NEW-OUTPUTS.txt
```

**What gets created:**
- ✅ VPC + subnets + NAT gateway
- ✅ EKS cluster + node group
- ✅ ECR repositories (backend + frontend)
- ✅ RDS PostgreSQL database
- ✅ IAM roles + Jenkins user
- ✅ Secrets Manager (RDS password)
- ✅ Jenkins EC2 instance

### 3.2 Configure kubectl

```bash
# Update kubeconfig for new cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name modena-dev-eks \
  --profile new-admin

# Verify cluster access
kubectl get nodes
kubectl get pods -n kube-system
```

### 3.3 Deploy ALB Controller

Terraform already deployed it via `load-balancer-controller` module. Verify:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
# Should show: 2/2 Ready

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
# Should show: 2x Running pods
```

---

## Phase 4: Container Images

### 4.1 Build and Push Backend Image

```bash
cd ~/modena/app/backend

# Get new Account ID and ECR login
export NEW_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile new-admin)
export AWS_PROFILE=new-admin

# Login to ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
  $NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t modena-backend:latest .

# Tag for ECR
docker tag modena-backend:latest \
  $NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/modena-dev-backend:latest

# Push to ECR
docker push $NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/modena-dev-backend:latest
```

### 4.2 Build and Push Frontend Image

```bash
cd ~/modena/app/frontend

# Build
docker build -t modena-frontend:latest .

# Tag + Push
docker tag modena-frontend:latest \
  $NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/modena-dev-frontend:latest

docker push $NEW_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/modena-dev-frontend:latest
```

### 4.3 Verify Images in New ECR

```bash
aws ecr describe-repositories --region us-east-1 --profile new-admin
aws ecr list-images --repository-name modena-dev-backend --region us-east-1 --profile new-admin
```

---

## Phase 5: Kubernetes Manifests

### 5.1 Create Namespace

```bash
kubectl create namespace modena-app
kubectl label namespace modena-app environment=dev
```

### 5.2 Update Image References

**File: `k8s/base/deployment-backend.yaml`**

Change the image URL to new ECR account:

```yaml
image: XXXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/modena-dev-backend:latest
# Replace XXXXXXXXXXXXX with NEW_ACCOUNT_ID
```

**File: `k8s/base/deployment-frontend.yaml`**

```yaml
image: XXXXXXXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/modena-dev-frontend:latest
```

### 5.3 Deploy Manifests

```bash
cd ~/modena

# Deploy base resources
kubectl apply -k k8s/overlays/dev

# Verify deployment
kubectl get pods -n modena-app
kubectl logs -n modena-app -l app=backend
```

---

## Phase 6: Ingress + ALB Endpoint

### 6.1 Create Ingress Resource

**File: `k8s/base/ingress.yaml`** (create if not exists)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: modena-ingress
  namespace: modena-app
  annotations:
    alb.ingress.kubernetes.io/load-balancer-type: application
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

### 6.2 Deploy Ingress

```bash
kubectl apply -f k8s/base/ingress.yaml

# Wait for ALB to be created (~2 minutes)
kubectl describe ingress modena-ingress -n modena-app

# Get the ALB endpoint
kubectl get ingress modena-ingress -n modena-app -o wide
# Address column = your ALB DNS name
```

---

## Phase 7: Database + Secrets

### 7.1 RDS Connection

**Get RDS endpoint:**
```bash
terraform output rds_endpoint
# Output: modena-dev-db.xxxxx.us-east-1.rds.amazonaws.com:5432
```

**Get RDS credentials:**
```bash
# From Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id dev-rds-password \
  --region us-east-1 \
  --profile new-admin
```

### 7.2 Initialize Database

```bash
# Connect to RDS
psql -h <RDS_ENDPOINT> -U modena_admin -d modena

# Run migrations (if using Alembic/Flyway)
# Or execute SQL schema files
```

---

## Phase 8: Jenkins (Optional)

### 8.1 Access Jenkins

```bash
# Get Jenkins URL
terraform output jenkins_url

# Get initial admin password
aws ssm get-parameter \
  --name /modena/jenkins/initial-password \
  --region us-east-1 \
  --profile new-admin
```

### 8.2 Configure Jenkins

1. Log in to Jenkins UI
2. Install plugins: Pipeline, GitHub, Docker, AWS
3. Configure credentials: GitHub token, AWS access key, Docker registry
4. Create pipeline job from GitHub repo

---

## Phase 9: Verification Checklist

```bash
# ✅ AWS Infrastructure
terraform output
aws ec2 describe-vpcs --region us-east-1 --profile new-admin | grep modena-dev

# ✅ EKS Cluster
kubectl get nodes
kubectl get pods -n kube-system

# ✅ Container Images
aws ecr list-images --repository-name modena-dev-backend --profile new-admin
aws ecr list-images --repository-name modena-dev-frontend --profile new-admin

# ✅ Application Pods
kubectl get pods -n modena-app
kubectl describe svc backend -n modena-app

# ✅ ALB Endpoint
kubectl get ingress -n modena-app -o wide
# Test: curl <ALB_DNS>/api/health

# ✅ Database
psql -h $(terraform output -raw rds_endpoint | cut -d: -f1) -U modena_admin -d modena -c "SELECT 1;"

# ✅ All resources tagged correctly
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Project,Values=modena" --profile new-admin
```

---

## Phase 10: Cleanup (Old Account)

**Only after new account is verified working:**

```bash
# Delete old account resources
cd terraform/environments/dev
export AWS_PROFILE=top-admin  # Old account profile

terraform destroy -auto-approve -lock=false

# Account can now be deleted
```

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `aws sts get-caller-identity` fails | Check credentials in `~/.aws/credentials`, verify profile name in `AWS_PROFILE` |
| `terraform init` fails | Delete `.terraform/` directory, run `terraform init` again |
| Pods stuck in `ImagePullBackOff` | ECR image not pushed, or image URI incorrect in deployment |
| ALB not created | Check ALB controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` |
| RDS connection fails | Check security group rules, verify endpoint URL, check credentials |
| kubectl can't connect | Run `aws eks update-kubeconfig` with correct cluster name and region |

---

## Key Files Modified

```
terraform/environments/dev/terraform.tfvars              ← NEW ACCOUNT ID
k8s/base/deployment-backend.yaml                        ← NEW ECR ARN
k8s/base/deployment-frontend.yaml                       ← NEW ECR ARN
k8s/base/ingress.yaml                                   ← (create if new)
```

---

## Timeline Estimate

- Phase 1 (Export): 10 minutes
- Phase 2 (Setup): 15 minutes
- Phase 3 (Infrastructure): 20 minutes
- Phase 4 (Images): 10 minutes
- Phase 5 (Kubernetes): 5 minutes
- Phase 6 (Ingress): 5 minutes
- Phase 7 (Database): 10 minutes
- Phase 8 (Jenkins): 10 minutes
- Phase 9 (Verification): 10 minutes

**Total: ~95 minutes (~1.5 hours)**

---

## Notes

- All infrastructure is **code** → fully reproducible
- Docker Compose file (`docker-compose.yml`) is for local development, not needed in new account
- GitHub workflows (if any) remain the same, just update AWS credentials
- Tag the migration in git: `git tag -a v0.4-new-account-migration`
- Keep `.github/copilot-instructions.md` in sync with any architectural changes
