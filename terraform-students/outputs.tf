# Root module outputs for the student variant.

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application)"
  value       = module.alb.alb_dns_name
}

output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = module.vpc.vpc_id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host (SSH to this first, then hop to APP instances)"
  value       = module.bastion.bastion_public_ip
}

output "ssm_private_key_parameter" {
  description = "SSM Parameter Store path for the bastion SSH private key"
  value       = module.bastion.ssm_parameter_name
}
