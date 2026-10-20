data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "opspulse" {
  name = "${var.project_name}-ec2"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Project = var.project_name
  }
}

resource "aws_security_group" "opspulse" {
  name        = "${var.project_name}-web"
  description = "Public HTTP only; administration and deployment use Systems Manager"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    description = "Public HTTP dashboard"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP package mirrors"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS package mirrors, image registry, and Systems Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.opspulse.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.opspulse.name
  user_data                   = file("${path.module}/user_data.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name    = "${var.project_name}-root"
      Project = var.project_name
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data_replace_on_change = false

  lifecycle {
    # Keep routine AMI publication from replacing the existing portfolio instance.
    ignore_changes = [ami]
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}
