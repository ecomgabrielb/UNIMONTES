# Bastion Module - Public bastion host for SSH access to private instances
# Creates a key pair, stores the private key in SSM Parameter Store,
# and launches a bastion EC2 instance in the public subnet.

# ------------------------------------------------------------------------------
# Data Source: Amazon Linux 2023 AMI
# ------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ------------------------------------------------------------------------------
# TLS Private Key and AWS Key Pair
# ------------------------------------------------------------------------------
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh

  tags = {
    Name = "${var.project_name}-bastion-key"
  }
}

# ------------------------------------------------------------------------------
# SSM Parameter Store - Private Key
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "bastion_private_key" {
  name        = "/${var.project_name}/bastion-private-key"
  description = "Private SSH key for the bastion host (use to connect to APP instances)"
  type        = "SecureString"
  value       = tls_private_key.bastion.private_key_pem

  tags = {
    Name = "${var.project_name}-bastion-private-key"
  }
}

# ------------------------------------------------------------------------------
# Bastion EC2 Instance
# ------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.bastion_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  tags = {
    Name = "bastion-${var.project_name}"
  }
}
