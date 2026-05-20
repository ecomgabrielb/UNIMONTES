output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "alb_subnet_ids" {
  description = "List of ALB_Layer (public) subnet IDs"
  value       = aws_subnet.alb[*].id
}

output "app_subnet_ids" {
  description = "List of APP_Layer (private) subnet IDs"
  value       = aws_subnet.app[*].id
}

output "services_subnet_id" {
  description = "ID of the Services subnet (NAT Gateway + Bastion)"
  value       = aws_subnet.services.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway in the Services subnet"
  value       = aws_nat_gateway.main.id
}
