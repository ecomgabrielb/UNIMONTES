# Bastion Module - Input Variables

variable "bastion_subnet_id" {
  description = "ID of the Services subnet for bastion placement"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the bastion host"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Project name used as prefix for resource naming"
  type        = string
}
