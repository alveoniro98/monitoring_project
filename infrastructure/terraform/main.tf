resource "aws_security_group" "opspulse" {
  name        = "${var.project_name}-web"
  description = "Minimum inbound access for OpsPulse public web demo"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    description = "Public HTTP dashboard"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.ssh_ingress_cidr == null ? [] : [var.ssh_ingress_cidr]
    content {
      description = "SSH from administrator public IP only"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Outbound updates and image build dependencies"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web"
    Project = var.project_name
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_instance" "opspulse" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.opspulse.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 16
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}
