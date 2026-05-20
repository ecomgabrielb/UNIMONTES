variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix for resource naming"
  type        = string
  default     = "resilient-web-server"
}
