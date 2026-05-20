# CloudWatch Module

## Purpose

Provides CPU monitoring, CloudWatch alarms, and SNS email notifications for the Auto Scaling Group. This module creates two metric alarms that monitor average CPU utilization and trigger scaling actions when thresholds are breached:

- **High CPU Alarm**: Triggers scale-out when CPU > 80% for 3 consecutive 10-second periods (30s total)
- **Low CPU Alarm**: Triggers scale-in when CPU < 40% for 3 consecutive 10-second periods (30s total)

Both alarms also publish notifications to an SNS topic with an email subscription, ensuring operators are informed of scaling events.

## Input Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `asg_name` | `string` | — | Name of the Auto Scaling Group to monitor for CPU utilization |
| `scale_out_policy_arn` | `string` | — | ARN of the ASG scale-out policy to trigger when CPU exceeds threshold |
| `scale_in_policy_arn` | `string` | — | ARN of the ASG scale-in policy to trigger when CPU drops below threshold |
| `alarm_notification_email` | `string` | — | Email address to receive CloudWatch alarm notifications via SNS |
| `project_name` | `string` | — | Project name used as prefix for all resources |

## Outputs

| Name | Description |
|------|-------------|
| `high_cpu_alarm_arn` | ARN of the high CPU utilization CloudWatch alarm |
| `low_cpu_alarm_arn` | ARN of the low CPU utilization CloudWatch alarm |
| `sns_topic_arn` | ARN of the SNS topic for alarm notifications |

## Usage Example

```hcl
module "cloudwatch" {
  source = "./modules/cloudwatch"

  asg_name                 = module.asg.asg_name
  scale_out_policy_arn     = module.asg.scale_out_policy_arn
  scale_in_policy_arn      = module.asg.scale_in_policy_arn
  alarm_notification_email = var.alarm_notification_email
  project_name             = var.project_name
}
```

## Resources Created

- `aws_sns_topic` — SNS topic for alarm notifications
- `aws_sns_topic_subscription` — Email subscription to the SNS topic
- `aws_cloudwatch_metric_alarm` (high_cpu) — Alarm for CPU > 80%, triggers scale-out + SNS notification
- `aws_cloudwatch_metric_alarm` (low_cpu) — Alarm for CPU < 40%, triggers scale-in + SNS notification

## Alarm Behavior

- **Period**: 10 seconds per data point
- **Evaluation Periods**: 3 consecutive periods (30 seconds total)
- **Missing Data**: Treated as "missing" — alarm maintains current state without triggering actions
- **Statistic**: Average CPU utilization across all ASG instances
- **Dimension**: Scoped to the specific ASG via `AutoScalingGroupName`

## SNS Email Subscription

After deployment, the email subscriber will receive a confirmation email from AWS. The subscription must be confirmed by clicking the link in the email before notifications will be delivered.
