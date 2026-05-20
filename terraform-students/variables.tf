variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "resilient-web-server"
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (/24)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "alarm_notification_email" {
  description = "Email address to receive CloudWatch alarm notifications via SNS"
  type        = string
}

variable "asg_min" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_max" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "asg_desired" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}
