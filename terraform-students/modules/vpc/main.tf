################################################################################
# VPC - /24 (256 addresses)
# Subnet layout using /27 (32 addresses each):
#   0: ALB_Layer AZ-1 (public)      - 10.0.0.0/27
#   1: ALB_Layer AZ-2 (public)      - 10.0.0.32/27
#   2: APP_Layer AZ-1 (private)     - 10.0.0.64/27
#   3: APP_Layer AZ-2 (private)     - 10.0.0.96/27
#   4: Services subnet AZ-1 (public) - 10.0.0.128/27 (NAT GW + Bastion)
#   5-7: Reserved for future use
#
# Layer approach:
#   ALB_Layer  → internet-facing, hosts ALB only
#   APP_Layer  → private, hosts web server instances
#   Services   → public, hosts NAT Gateway and Bastion host
################################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

################################################################################
# ALB_Layer Subnets (Public) - /27 each
# cidrsubnet(10.0.0.0/24, 3, 0) = 10.0.0.0/27
# cidrsubnet(10.0.0.0/24, 3, 1) = 10.0.0.32/27
################################################################################

resource "aws_subnet" "alb" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-alb-subnet-${count.index + 1}"
    Tier = "ALB_Layer"
  }
}

################################################################################
# APP_Layer Subnets (Private) - /27 each
# cidrsubnet(10.0.0.0/24, 3, 2) = 10.0.0.64/27
# cidrsubnet(10.0.0.0/24, 3, 3) = 10.0.0.96/27
################################################################################

resource "aws_subnet" "app" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index + 2)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-app-subnet-${count.index + 1}"
    Tier = "APP_Layer"
  }
}

################################################################################
# Services Subnet (Public) - /27 - Hosts NAT Gateway + Bastion
# cidrsubnet(10.0.0.0/24, 3, 4) = 10.0.0.128/27
################################################################################

resource "aws_subnet" "services" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, 4)
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-services-subnet"
    Tier = "Services"
  }
}

################################################################################
# NAT Gateway (in Services subnet)
################################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.services.id

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# Route Tables - Public (ALB_Layer + Services → IGW)
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "alb" {
  count = 2

  subnet_id      = aws_subnet.alb[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "services" {
  subnet_id      = aws_subnet.services.id
  route_table_id = aws_route_table.public.id
}

################################################################################
# Route Tables - Private (APP_Layer → NAT Gateway)
################################################################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "app" {
  count = 2

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

################################################################################
# Network ACL - ALB_Layer
# Purpose: Only HTTP from internet (for ALB listeners)
# No SSH, no direct access — ALB only.
################################################################################

resource "aws_network_acl" "alb" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.alb[*].id

  # Inbound: HTTP from internet (client requests to ALB)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Inbound: Ephemeral ports from APP subnets (health check responses)
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Inbound: Ephemeral ports from internet (return traffic for client responses)
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: HTTP to APP subnets (ALB forwarding to targets)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 80
    to_port    = 80
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Outbound: Ephemeral ports to internet (responses to clients)
  egress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-alb-nacl"
  }
}

################################################################################
# Network ACL - APP_Layer (Private)
# Purpose: Only accepts HTTP from ALB subnets, SSH from Services subnet.
# Outbound: responses to ALB/Services, and internet access via NAT.
################################################################################

resource "aws_network_acl" "app" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.app[*].id

  # Inbound: HTTP from ALB subnet AZ1
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.alb[0].cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Inbound: HTTP from ALB subnet AZ2
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.alb[1].cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Inbound: SSH from Services subnet (bastion)
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.services.cidr_block
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports (return traffic from internet via NAT)
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Ephemeral ports to ALB subnets (HTTP responses to ALB)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.alb[0].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.alb[1].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Ephemeral ports to Services subnet (SSH responses to bastion)
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.services.cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: HTTP to internet (yum repos via NAT in Services subnet)
  egress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Outbound: HTTPS to internet (yum repos via NAT in Services subnet)
  egress {
    rule_no    = 210
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = {
    Name = "${var.project_name}-app-nacl"
  }
}

################################################################################
# Network ACL - Services Subnet (NAT Gateway + Bastion)
# Purpose: SSH from internet (bastion), NAT Gateway traffic.
################################################################################

resource "aws_network_acl" "services" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.services.id]

  # Inbound: SSH from internet (bastion access)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Inbound: HTTP from APP subnets (NAT Gateway - outbound traffic from instances)
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 80
    to_port    = 80
  }

  # Inbound: HTTPS from APP subnets (NAT Gateway - outbound traffic from instances)
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 140
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 443
    to_port    = 443
  }

  # Inbound: Ephemeral ports from APP subnets (SSH responses from instances to bastion)
  ingress {
    rule_no    = 150
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    rule_no    = 160
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Inbound: Ephemeral ports from internet (return traffic for NAT + bastion SSH)
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: SSH to APP subnets (bastion → instances)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 22
    to_port    = 22
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 22
    to_port    = 22
  }

  # Outbound: HTTP/HTTPS to internet (NAT Gateway forwarding)
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports to APP subnets (NAT return traffic to instances)
  egress {
    rule_no    = 140
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[0].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 150
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_subnet.app[1].cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Ephemeral ports to internet (SSH responses to bastion clients)
  egress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-services-nacl"
  }
}
