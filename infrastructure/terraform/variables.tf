variable "aws_region" {
  description = "AWS region in which to create the optional EC2 instance."
  type        = string
  default     = "ap-southeast-3"
}

variable "ami_id" {
  description = "Ubuntu Server AMI ID for the selected AWS region."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type; verify its capacity and cost for your region."
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Subnet ID in which the instance will be created."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair. The private key stays outside Terraform."
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "Your public IPv4 CIDR for SSH, for example 203.0.113.10/32. Null disables SSH ingress."
  type        = string
  default     = null
  nullable    = true
}

variable "project_name" {
  description = "Resource name prefix."
  type        = string
  default     = "opspulse"
}
