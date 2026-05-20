# Bastion Module - Outputs

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = aws_instance.bastion.id
}

output "key_pair_name" {
  description = "Name of the SSH key pair (also used by ASG instances)"
  value       = aws_key_pair.bastion.key_name
}

output "ssm_parameter_name" {
  description = "SSM Parameter Store path for the private key"
  value       = aws_ssm_parameter.bastion_private_key.name
}
