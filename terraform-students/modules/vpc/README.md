# VPC Module

## Purpose

Provisions a two-layer VPC network architecture across two Availability Zones. The VPC contains:

- **ALB_Layer** (public subnets): Hosts the Application Load Balancer and NAT Gateway
- **APP_Layer** (private subnets): Hosts the EC2 application instances

A single NAT Gateway is deployed in AZ-1 to minimize cost while providing outbound internet access for private instances.

## CIDR Allocation

For a VPC CIDR of `10.0.0.0/24`:

| Subnet | CIDR | Addresses |
|--------|------|-----------|
| ALB subnet AZ-1 | 10.0.0.0/26 | 64 |
| ALB subnet AZ-2 | 10.0.0.64/26 | 64 |
| APP subnet AZ-1 | 10.0.0.128/26 | 64 |
| APP subnet AZ-2 | 10.0.0.192/26 | 64 |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `vpc_cidr` | CIDR block for the VPC (must be /24) | `string` | yes |
| `azs` | List of two Availability Zones for subnet deployment | `list(string)` | yes |
| `project_name` | Project name used as prefix for resource naming | `string` | yes |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the provisioned VPC |
| `alb_subnet_ids` | List of ALB_Layer (public) subnet IDs |
| `app_subnet_ids` | List of APP_Layer (private) subnet IDs |
| `nat_gateway_id` | ID of the single NAT Gateway in ALB_Layer AZ-1 |

## Usage Example

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = "10.0.0.0/24"
  azs          = ["us-east-1a", "us-east-1b"]
  project_name = "resilient-web-server"
}
```
