variable "alb_sg_id" {
  description = "ID of the security group to attach to the ALB"
  type        = string
}

variable "alb_subnet_ids" {
  description = "List of public subnet IDs (ALB_Layer) where the ALB will be deployed"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC for the target group"
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix for resource naming"
  type        = string
  default     = "resilient-web-server"
}
