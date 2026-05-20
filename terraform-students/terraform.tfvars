# Student Variant - Example Variable Values
# Copy this file to terraform.tfvars and update with your values.

project_name             = "resilient-web-server"
aws_region               = "us-east-1"
vpc_cidr                 = "10.0.0.0/24"
instance_type            = "t3.micro"
alarm_notification_email = "curd_duality.4w@icloud.com"

# Auto Scaling Group
asg_min     = 2
asg_max     = 4
asg_desired = 2
