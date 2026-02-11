#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# JENKINS BOOTSTRAP SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════

set -e
exec > >(tee /var/log/userdata.log) 2>&1

echo "Starting Jenkins bootstrap for ${project_name}-${environment}"

# System Update
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Java 17
apt-get install -y openjdk-17-jdk

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" | \
    tee /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update
apt-get install -y jenkins

# Install Docker
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
usermod -aG docker jenkins
systemctl enable docker
systemctl start docker

# Install AWS CLI v2
apt-get install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
mv kustomize /usr/local/bin/

# Install Checkov (YOUR INTERVIEW GAP - NOW FIXED!)
apt-get install -y python3-pip
pip3 install checkov

# Install TFSec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Install Trivy
apt-get install -y wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
    gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
    https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/trivy.list > /dev/null
apt-get update
apt-get install -y trivy

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

# Configure Jenkins user
mkdir -p /var/lib/jenkins/.aws
mkdir -p /var/lib/jenkins/.kube
chown -R jenkins:jenkins /var/lib/jenkins/.aws
chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Start Jenkins
systemctl enable jenkins
systemctl start jenkins

echo "═══════════════════════════════════════════════════════════════════"
echo "JENKINS BOOTSTRAP COMPLETE!"
echo "Get password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "═══════════════════════════════════════════════════════════════════"