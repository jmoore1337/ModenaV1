# JENKINS EC2 DEPLOYMENT GUIDE
# Complete Instructions from Zero to Running Pipeline

---

## WHAT YOU'RE ABOUT TO CREATE

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           JENKINS ON EC2                                         │
└─────────────────────────────────────────────────────────────────────────────────┘

YOUR VPC (10.0.0.0/16)
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│   PUBLIC SUBNET (10.0.1.0/24)                                                   │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                         │  │
│   │   ┌─────────────────────────────────────────┐                          │  │
│   │   │         JENKINS EC2 (t3.medium)         │                          │  │
│   │   │                                         │                          │  │
│   │   │  • Java 17                              │                          │  │
│   │   │  • Jenkins LTS                          │                          │  │
│   │   │  • Docker                               │                          │  │
│   │   │  • AWS CLI                              │                          │  │
│   │   │  • kubectl + kustomize                  │                          │  │
│   │   │  • Checkov + TFSec + Trivy              │                          │  │
│   │   │                                         │                          │  │
│   │   │  IAM Role: modena-dev-jenkins-role      │                          │  │
│   │   │  • ECR push/pull                        │                          │  │
│   │   │  • EKS describe                         │                          │  │
│   │   │  • Secrets Manager read                 │                          │  │
│   │   │                                         │                          │  │
│   │   │  Security Group:                        │                          │  │
│   │   │  • 22 (SSH) from YOUR IP only           │                          │  │
│   │   │  • 8080 (Jenkins) from YOUR IP only     │                          │  │
│   │   │                                         │                          │  │
│   │   │  Elastic IP: x.x.x.x (stable)           │                          │  │
│   │   └─────────────────────────────────────────┘                          │  │
│   │                                                                         │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
│   PRIVATE SUBNET (10.0.3.0/24)                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐  │
│   │   EKS Worker Node                     RDS PostgreSQL                    │  │
│   │   (Jenkins deploys here)              (Jenkins tests connect here)      │  │
│   └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## PREREQUISITES

Before deploying Jenkins, you need:

1. **VPC deployed** (you already have this!)
2. **EKS deployed** (you already have this!)
3. **EC2 Key Pair** in AWS (for SSH access)
4. **Your public IP** (for security group)

### Create EC2 Key Pair (if you don't have one)

```bash
# Option 1: Create in AWS Console
# EC2 → Key Pairs → Create key pair → Name: modena-key → RSA → .pem

# Option 2: Create via CLI
aws ec2 create-key-pair \
    --key-name modena-key \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/modena-key.pem

chmod 400 ~/.ssh/modena-key.pem
```

### Get Your Public IP

```bash
curl ifconfig.me
# Output: 1.2.3.4 (your IP)
```

---

## STEP 1: COPY MODULE TO YOUR PROJECT

```bash
# Create jenkins module directory
mkdir -p ~/modena/terraform/modules/jenkins

# Copy all module files
cp main.tf ~/modena/terraform/modules/jenkins/
cp iam.tf ~/modena/terraform/modules/jenkins/
cp variables.tf ~/modena/terraform/modules/jenkins/
cp outputs.tf ~/modena/terraform/modules/jenkins/
cp userdata.sh ~/modena/terraform/modules/jenkins/
```

---

## STEP 2: ADD VARIABLES TO DEV ENVIRONMENT

Edit `~/modena/terraform/environments/dev/variables.tf`:

```hcl
# Add these variables

variable "jenkins_allowed_cidrs" {
  description = "CIDR blocks allowed to access Jenkins"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}
```

Edit `~/modena/terraform/environments/dev/terraform.tfvars`:

```hcl
# Add these values (use YOUR actual IP!)
jenkins_allowed_cidrs = ["YOUR.IP.ADDRESS/32"]  # Example: ["1.2.3.4/32"]
key_name              = "modena-key"             # Your key pair name
```

---

## STEP 3: ADD JENKINS MODULE TO DEV

Create `~/modena/terraform/environments/dev/jenkins.tf`:

```hcl
module "jenkins" {
  source = "../../modules/jenkins"

  project_name = var.project_name
  environment  = var.environment

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]

  allowed_cidr_blocks = var.jenkins_allowed_cidrs
  key_name            = var.key_name
  eks_cluster_name    = module.eks.cluster_name
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}

output "jenkins_ssh" {
  value = module.jenkins.ssh_command
}

output "jenkins_iam_role_arn" {
  value = module.jenkins.jenkins_iam_role_arn
}
```

---

## STEP 4: DEPLOY JENKINS

```bash
cd ~/modena/terraform/environments/dev

# Initialize (downloads provider, initializes module)
terraform init

# Preview what will be created
terraform plan

# Deploy!
terraform apply
```

Expected output:
```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

jenkins_url = "http://3.91.123.45:8080"
jenkins_ssh = "ssh -i ~/.ssh/modena-key.pem ubuntu@3.91.123.45"
jenkins_iam_role_arn = "arn:aws:iam::730335375020:role/modena-dev-jenkins-role"
```

---

## STEP 5: WAIT FOR BOOTSTRAP (5-10 minutes)

The user_data script installs everything. Wait for it to complete.

```bash
# SSH into Jenkins
ssh -i ~/.ssh/modena-key.pem ubuntu@<JENKINS_IP>

# Check bootstrap progress
tail -f /var/log/userdata.log

# When you see "JENKINS BOOTSTRAP COMPLETE!", it's done!
```

---

## STEP 6: GET JENKINS ADMIN PASSWORD

```bash
# On the Jenkins EC2 (via SSH)
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Copy this password!

---

## STEP 7: ACCESS JENKINS UI

1. Open browser: `http://<JENKINS_IP>:8080`
2. Paste the admin password
3. Click "Install suggested plugins" (wait 5 minutes)
4. Create admin user
5. Click "Start using Jenkins"

---

## STEP 8: INSTALL ADDITIONAL PLUGINS

In Jenkins UI:

1. Manage Jenkins → Plugins → Available plugins
2. Search and install:
   - **Docker Pipeline**
   - **Amazon ECR**
   - **Pipeline: AWS Steps**
   - **Kubernetes CLI**
3. Restart Jenkins when prompted

---

## STEP 9: ADD JENKINS ROLE TO EKS

Jenkins needs permission to deploy to EKS. Add its IAM role to aws-auth:

```bash
# Get the Jenkins IAM role ARN from Terraform output
JENKINS_ROLE_ARN="arn:aws:iam::730335375020:role/modena-dev-jenkins-role"

# Option 1: Use eksctl (easier)
eksctl create iamidentitymapping \
    --cluster modena-dev-eks \
    --region us-east-1 \
    --arn $JENKINS_ROLE_ARN \
    --username jenkins \
    --group system:masters

# Option 2: Edit ConfigMap manually
kubectl edit configmap aws-auth -n kube-system

# Add under mapRoles:
#   - rolearn: arn:aws:iam::730335375020:role/modena-dev-jenkins-role
#     username: jenkins
#     groups:
#       - system:masters
```

---

## STEP 10: CREATE PIPELINE JOB

1. Jenkins Dashboard → New Item
2. Name: **modena-pipeline**
3. Type: **Pipeline**
4. Click OK

In Pipeline configuration:
- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `https://github.com/YOUR_USER/modena.git`
- Branch: `*/main`
- Script Path: `jenkins/Jenkinsfile`

Click Save.

---

## STEP 11: CONFIGURE GITHUB WEBHOOK

In your GitHub repo:

1. Settings → Webhooks → Add webhook
2. Payload URL: `http://<JENKINS_IP>:8080/github-webhook/`
3. Content type: `application/json`
4. Events: "Just the push event"
5. Active: ✓
6. Click "Add webhook"

---

## STEP 12: TEST THE PIPELINE!

Option 1: **Manual trigger**
- Jenkins → modena-pipeline → Build Now
- Watch Console Output

Option 2: **Automatic trigger**
- Push a commit to GitHub
- Watch Jenkins start automatically!

---

## TROUBLESHOOTING

### Can't access Jenkins UI

```bash
# Check security group allows your IP
# Your IP might have changed! Update terraform.tfvars

# Check Jenkins is running
ssh -i ~/.ssh/modena-key.pem ubuntu@<IP>
sudo systemctl status jenkins
```

### Docker permission denied

```bash
# Ensure jenkins user is in docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### kubectl can't connect to EKS

```bash
# Check IAM role is in aws-auth ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml

# Should see jenkins role listed under mapRoles
```

### ECR push fails with 403

```bash
# Check IAM policy allows ECR access
# The policy restricts to modena-* repos
# Make sure your ECR repo name starts with "modena-"
```

---

## COST ESTIMATE

```
Jenkins EC2 (t3.medium):
- On-demand: $0.0416/hour × 24 × 30 = ~$30/month
- Elastic IP: Free when attached to running instance
- EBS (50GB gp3): ~$4/month

Total: ~$35/month running 24/7

TO SAVE MONEY:
- Stop instance when not using: ~$5-10/month
- Or destroy after testing: $0
```

---

## INTERVIEW TALKING POINTS

After completing this deployment:

> "I provisioned Jenkins on EC2 using Terraform with an IAM instance profile
> instead of stored credentials. The security group restricts access to specific
> IPs, and user_data automates complete server setup including Docker, kubectl,
> and security scanning tools like Checkov, TFSec, and Trivy."

> "The Jenkins IAM role follows least privilege - it can only push to ECR repos
> starting with our project name, only describe our EKS clusters, and only read
> secrets prefixed with our project name."

> "I mapped the Jenkins IAM role to Kubernetes RBAC via the aws-auth ConfigMap.
> EKS authorization is two-step: IAM grants API access, aws-auth maps to K8s
> permissions."
