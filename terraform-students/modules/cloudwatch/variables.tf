# CloudWatch Module - Input Variables

variable "asg_name" {
  description = "Name of the Auto Scaling Group to monitor for CPU utilization"
  type        = string
}

variable "alarm_notification_email" {
  description = "Email address to receive CloudWatch alarm notifications via SNS"
  type        = string
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
}
