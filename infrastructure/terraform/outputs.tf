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
