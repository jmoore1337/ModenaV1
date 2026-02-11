# ═══════════════════════════════════════════════════════════════════════════════
# JENKINS MODULE - outputs.tf
# ═══════════════════════════════════════════════════════════════════════════════

output "jenkins_url" {
  description = "URL to access Jenkins web UI"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"
}

output "jenkins_public_ip" {
  description = "Jenkins Elastic IP address"
  value       = aws_eip.jenkins.public_ip
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_security_group_id" {
  description = "Jenkins security group ID"
  value       = aws_security_group.jenkins.id
}

output "jenkins_iam_role_arn" {
  description = "Jenkins IAM role ARN (for aws-auth ConfigMap)"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_iam_role_name" {
  description = "Jenkins IAM role name"
  value       = aws_iam_role.jenkins.name
}

output "github_webhook_url" {
  description = "URL to configure in GitHub webhook settings"
  value       = "http://${aws_eip.jenkins.public_ip}:8080/github-webhook/"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_eip.jenkins.public_ip}"
}

output "initial_password_command" {
  description = "Command to get Jenkins initial admin password"
  value       = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}