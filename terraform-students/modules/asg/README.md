# ASG Module

## Purpose

Manages the EC2 instance lifecycle with CPU-based auto scaling. This module provisions a launch template with Amazon Linux 2023, an Auto Scaling Group that maintains 2-4 instances across multiple Availability Zones, and simple scaling policies for scale-out and scale-in actions.

The launch template includes a UserData script that:
- Installs and enables Apache HTTPD
- Installs stress-ng for CPU load testing
- Retrieves instance metadata (instance ID and AZ) with retry logic (3 attempts, 5s delay)
- Generates an index.html page displaying instance identity

## Input Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_subnet_ids` | `list(string)` | — | List of APP_Layer (private) subnet IDs where EC2 instances will be launched |
| `app_sg_id` | `string` | — | Security group ID for the application tier EC2 instances |
| `target_group_arn` | `string` | — | ARN of the ALB target group to register instances with |
| `instance_profile_name` | `string` | — | Name of the IAM instance profile for SSM access |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type for web servers |
| `project_name` | `string` | — | Project name used as prefix for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `asg_name` | Name of the Auto Scaling Group |
| `asg_arn` | ARN of the Auto Scaling Group |
| `scale_out_policy_arn` | ARN of the scale-out autoscaling policy |
| `scale_in_policy_arn` | ARN of the scale-in autoscaling policy |

## Usage Example

```hcl
module "asg" {
  source = "./modules/asg"

  app_subnet_ids        = module.vpc.app_subnet_ids
  app_sg_id             = module.security_groups.app_sg_id
  target_group_arn      = module.alb.target_group_arn
  instance_profile_name = module.ssm.instance_profile_name
  instance_type         = var.instance_type
  project_name          = var.project_name
}
```

## Resources Created

- `aws_launch_template` — Launch template with Amazon Linux 2023 AMI, UserData, and instance profile
- `aws_autoscaling_group` — ASG with min:2, max:4, desired:2, ELB health checks, 30s grace period
- `aws_autoscaling_policy` (scale-out) — SimpleScaling +1 instance, 30s cooldown
- `aws_autoscaling_policy` (scale-in) — SimpleScaling -1 instance, 30s cooldown

## Scaling Behavior

- **Scale-out**: Triggered by CloudWatch alarm (CPU > 80%). Adds 1 instance per scaling action with 30s cooldown.
- **Scale-in**: Triggered by CloudWatch alarm (CPU < 40%). Removes 1 instance per scaling action with 30s cooldown.
- **Health checks**: ELB-based with 30s grace period for new instances.
