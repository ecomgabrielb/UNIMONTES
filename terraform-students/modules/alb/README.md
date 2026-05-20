# ALB Module (Student Variant - HTTP Only)

This module provisions an internet-facing Application Load Balancer for the student variant of the resilient web server infrastructure. Unlike the main variant (`terraform-main/`), this ALB operates exclusively over HTTP — no HTTPS listener, ACM certificate, or TLS termination is configured.

Students access the application directly via the ALB DNS name on port 80.

## Resources Created

- **Application Load Balancer** — Internet-facing, cross-zone load balancing enabled, deployed across ALB_Layer subnets
- **Target Group** — HTTP on port 80 with aggressive health checks for fast failover detection
- **HTTP Listener (port 80)** — Forwards traffic directly to the target group

## Health Check Configuration

| Parameter           | Value        |
|---------------------|--------------|
| Path                | /            |
| Protocol            | HTTP         |
| Interval            | 6 seconds    |
| Timeout             | 5 seconds    |
| Healthy threshold   | 2            |
| Unhealthy threshold | 2            |
| Matcher             | 200          |

## Input Variables

| Name            | Type         | Default                  | Description                                              |
|-----------------|--------------|--------------------------|----------------------------------------------------------|
| alb_sg_id       | string       | —                        | ID of the security group to attach to the ALB            |
| alb_subnet_ids  | list(string) | —                        | List of public subnet IDs (ALB_Layer) for ALB deployment |
| vpc_id          | string       | —                        | ID of the VPC for the target group                       |
| project_name    | string       | "resilient-web-server"   | Project name used as prefix for resource naming          |

## Outputs

| Name             | Description                                          |
|------------------|------------------------------------------------------|
| alb_dns_name     | DNS name of the Application Load Balancer            |
| alb_arn          | ARN of the Application Load Balancer                 |
| target_group_arn | ARN of the target group for instance registration    |
| alb_zone_id      | Hosted zone ID of the ALB (for Route 53 alias records) |

## Usage Example

```hcl
module "alb" {
  source = "./modules/alb"

  alb_sg_id      = module.security_groups.alb_sg_id
  alb_subnet_ids = module.vpc.alb_subnet_ids
  vpc_id         = module.vpc.vpc_id
  project_name   = var.project_name
}
```

## Differences from terraform-main ALB Module

| Feature              | terraform-main | terraform-students |
|----------------------|----------------|--------------------|
| HTTPS listener (443) | ✅              | ❌                  |
| ACM certificate      | ✅              | ❌                  |
| HTTP→HTTPS redirect  | ✅              | ❌                  |
| HTTP forward (80)    | ❌ (redirects)  | ✅                  |
| acm_cert_arn variable| ✅              | ❌                  |
