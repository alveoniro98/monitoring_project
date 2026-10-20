output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.opspulse.id
}

output "public_ip" {
  description = "Public IPv4 address; configure deployment and browser access with this value."
  value       = aws_instance.opspulse.public_ip
}

output "security_group_id" {
  description = "Security group attached to OpsPulse."
  value       = aws_security_group.opspulse.id
}

output "deployment_region" {
  description = "AWS region for the instance and Systems Manager commands."
  value       = var.aws_region
}

output "ssm_instance_profile" {
  description = "IAM instance profile for Systems Manager managed-instance access."
  value       = aws_iam_instance_profile.opspulse.name
}
