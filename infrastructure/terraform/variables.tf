variable "aws_region" {
  description = "AWS region in which to create the OpsPulse EC2 instance."
  type        = string
  default     = "ap-southeast-3"
}

variable "instance_type" {
  description = "EC2 instance type; confirm current regional pricing before applying."
  type        = string
  default     = "t3.small"
}

variable "subnet_id" {
  description = "Subnet ID in which the instance will be created."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-f]+$", var.subnet_id))
    error_message = "subnet_id must identify an existing AWS subnet."
  }
}

variable "project_name" {
  description = "Resource name prefix."
  type        = string
  default     = "opspulse"
}
