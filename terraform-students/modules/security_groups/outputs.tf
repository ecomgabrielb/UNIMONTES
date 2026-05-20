output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.app.id
}

output "bastion_sg_id" {
  description = "ID of the bastion host security group"
  value       = aws_security_group.bastion.id
}
