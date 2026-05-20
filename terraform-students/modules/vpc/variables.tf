variable "vpc_cidr" {
  description = "CIDR block for the VPC (must be /24)"
  type        = string
}

variable "azs" {
  description = "List of two Availability Zones for subnet deployment"
  type        = list(string)
}

variable "project_name" {
  description = "Project name used as prefix for resource naming"
  type        = string
}
