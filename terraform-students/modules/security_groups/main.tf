###############################################################################
# ALB Security Group
# Allows inbound HTTP (80) from the internet only (no HTTPS - student variant).
# Outbound restricted to APP SG on port 80.
###############################################################################

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from the internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow outbound HTTP to application instances"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

###############################################################################
# APP Security Group
# Allows inbound HTTP (80) from ALB SG and SSH (22) from Bastion SG.
# Outbound allows all traffic (instances reach internet via NAT Gateway).
###############################################################################

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow HTTP from ALB only"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_bastion_ssh" {
  security_group_id            = aws_security_group.app.id
  description                  = "Allow SSH from bastion host"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "app_all_outbound" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic (via NAT Gateway)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

###############################################################################
# Bastion Security Group
# Allows inbound SSH (22) from the internet.
# Outbound SSH (22) to APP SG.
###############################################################################

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for the bastion host"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow SSH from the internet"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "bastion_to_app_ssh" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Allow SSH to application instances"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}
