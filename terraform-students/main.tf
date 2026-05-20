terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-students"
      ManagedBy   = "terraform"
      Environment = "demo"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Module: VPC
# Provisions the two-layer network architecture across 2 AZs.
# -----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  project_name = var.project_name
}

# -----------------------------------------------------------------------------
# Module: Security Groups
# Defines all security group rules with least-privilege access.
# Depends on: VPC
# -----------------------------------------------------------------------------

module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
}

# -----------------------------------------------------------------------------
# Module: Bastion
# Public bastion host for SSH access to private APP instances.
# Depends on: VPC, Security Groups
# -----------------------------------------------------------------------------

module "bastion" {
  source = "./modules/bastion"

  bastion_subnet_id = module.vpc.services_subnet_id
  bastion_sg_id     = module.security_groups.bastion_sg_id
  instance_type     = var.instance_type
  project_name      = var.project_name
}

# -----------------------------------------------------------------------------
# Module: ALB
# Application Load Balancer with HTTP listener and health checks.
# Depends on: VPC, Security Groups
# -----------------------------------------------------------------------------

module "alb" {
  source = "./modules/alb"

  alb_sg_id      = module.security_groups.alb_sg_id
  alb_subnet_ids = module.vpc.alb_subnet_ids
  vpc_id         = module.vpc.vpc_id
  project_name   = var.project_name
}

# -----------------------------------------------------------------------------
# Module: ASG
# Manages EC2 instance lifecycle with CPU-based scaling.
# Depends on: VPC, Security Groups, ALB, Bastion (for key pair)
# -----------------------------------------------------------------------------

module "asg" {
  source = "./modules/asg"

  app_subnet_ids   = module.vpc.app_subnet_ids
  app_sg_id        = module.security_groups.app_sg_id
  target_group_arn = module.alb.target_group_arn
  instance_type    = var.instance_type
  key_name         = module.bastion.key_pair_name
  asg_min          = var.asg_min
  asg_max          = var.asg_max
  asg_desired      = var.asg_desired
  project_name     = var.project_name
}

# -----------------------------------------------------------------------------
# Module: CloudWatch
# CPU monitoring, alarms, and SNS notifications.
# Depends on: ASG
# -----------------------------------------------------------------------------

module "cloudwatch" {
  source = "./modules/cloudwatch"

  asg_name                 = module.asg.asg_name
  alarm_notification_email = var.alarm_notification_email
  project_name             = var.project_name
}

# -----------------------------------------------------------------------------
# Resource Group
# Groups all resources by the Project tag for easy management.
# -----------------------------------------------------------------------------

resource "aws_resourcegroups_group" "students" {
  name        = "${var.project_name}-students"
  description = "All resources for the resilient web server - student variant"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["terraform-students"]
        }
      ]
    })
  }

  tags = {
    Name = "${var.project_name}-students"
  }
}
