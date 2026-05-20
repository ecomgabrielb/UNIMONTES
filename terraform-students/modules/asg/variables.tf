# ASG Module - Input Variables

variable "app_subnet_ids" {
  description = "List of APP_Layer (private) subnet IDs where EC2 instances will be launched"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID for the application tier EC2 instances"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register instances with"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
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

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
}
