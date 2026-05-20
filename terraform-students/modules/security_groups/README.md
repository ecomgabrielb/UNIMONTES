# Security Groups Module (Student Variant)

## Purpose

Defines all security groups for the student variant of the resilient web server infrastructure with least-privilege access rules. This module creates three security groups:

- **ALB SG** — Allows inbound HTTP only (port 80) from the internet; outbound only to application instances on port 80. No HTTPS (443) since the student variant does not use an ACM certificate.
- **APP SG** — Allows inbound HTTP from the ALB security group only; all outbound (via NAT Gateway for package updates).
- **EICE SG** — No inbound rules; outbound TCP 22 to application instances only (for EC2 Instance Connect Endpoint).

No security group permits SSH (port 22) from 0.0.0.0/0 or any external source.

## Input Variables

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `vpc_id` | `string` | ID of the VPC where security groups will be created | — (required) |
| `project_name` | `string` | Project name used as prefix for resource naming | `"resilient-web-server"` |

## Outputs

| Name | Description |
|------|-------------|
| `alb_sg_id` | ID of the ALB security group |
| `app_sg_id` | ID of the application tier security group |
| `eice_sg_id` | ID of the EC2 Instance Connect Endpoint security group |

## Usage Example

```hcl
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
}
```

## Security Rules Summary

| Security Group | Inbound | Outbound |
|---------------|---------|----------|
| ALB SG | TCP 80 from 0.0.0.0/0 | TCP 80 to APP SG |
| APP SG | TCP 80 from ALB SG only | All (0.0.0.0/0 via NAT GW) |
| EICE SG | None | TCP 22 to APP SG |

## Differences from terraform-main

- ALB SG does **not** include an HTTPS (port 443) ingress rule since the student variant operates HTTP-only without an ACM certificate.
