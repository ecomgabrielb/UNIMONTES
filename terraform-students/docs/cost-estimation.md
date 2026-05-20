# Cost Estimation: Student Variant Infrastructure

This document provides a monthly and daily cost breakdown for all AWS resources provisioned by the student variant of the resilient web server infrastructure, enabling budget planning for running this demo environment.

**Key difference from terraform-main:** The student variant does not include Route 53, ACM, or CloudFront, resulting in lower overall costs.

## Pricing Assumptions

| Parameter | Value |
|-----------|-------|
| AWS Region | us-east-1 (N. Virginia) |
| Instance Type | t3.micro ($0.0104/hour On-Demand) |
| Monthly Uptime | 730 hours (continuous running) |
| Data Transfer (outbound) | ~10 GB/month estimate |
| LCU Baseline | 10 new connections/sec, 100 active connections, 1 GB processed bytes/hour, 10 rule evaluations/sec |
| Pricing Effective Date | January 2025 (approximate) |
| Free-Tier Discounts | Not applied |
| Pricing Model | On-Demand (no Reserved Instances or Savings Plans) |

## Monthly Cost Table

| Resource | Quantity | Unit Price | Monthly Cost (USD) |
|----------|----------|------------|-------------------|
| EC2 t3.micro (On-Demand) — ASG | 2 instances × 730h | $0.0104/h | $15.18 |
| EC2 t3.micro (On-Demand) — Bastion | 1 instance × 730h | $0.0104/h | $7.59 |
| ALB — Hourly | 1 × 730h | $0.0225/h | $16.43 |
| ALB — LCU | ~1 LCU avg | $0.008/LCU-h × 730h | $5.84 |
| NAT Gateway — Hourly | 1 × 730h | $0.045/h | $32.85 |
| NAT Gateway — Data Processing | 10 GB | $0.045/GB | $0.45 |
| **TOTAL** | | | **~$78.34** |

### Resources NOT included (student variant)

| Resource | Reason Excluded |
|----------|----------------|
| Route 53 — Hosted Zone | No custom domain; students use ALB DNS name directly |
| Route 53 — Queries | No DNS queries to Route 53 |
| ACM Certificate | No HTTPS; HTTP-only ALB |
| CloudFront | No CDN distribution |

## Daily Cost Breakdown

| Resource | Daily Cost (USD) |
|----------|-----------------|
| EC2 — ASG (2 instances) | $0.51 |
| EC2 — Bastion (1 instance) | $0.25 |
| ALB (hourly + LCU) | $0.74 |
| NAT Gateway (hourly + data) | $1.11 |
| **TOTAL** | **~$2.61/day** |

## Peak-Load Estimate (4 Instances)

When the ASG scales out to the maximum of 4 instances under sustained high CPU load:

| Resource | Calculation | Monthly Cost (USD) |
|----------|-------------|-------------------|
| EC2 t3.micro (On-Demand) — ASG | 4 instances × 730h × $0.0104/h | $30.37 |
| EC2 t3.micro (On-Demand) — Bastion | 1 instance × 730h × $0.0104/h | $7.59 |
| ALB — Hourly | 1 × 730h × $0.0225/h | $16.43 |
| ALB — LCU | ~1 LCU avg × 730h × $0.008/LCU-h | $5.84 |
| NAT Gateway — Hourly | 1 × 730h × $0.045/h | $32.85 |
| NAT Gateway — Data Processing | 10 GB × $0.045/GB | $0.45 |
| **TOTAL** | | **~$93.53** |

**Peak daily cost:** ~$3.12/day

## Summary

| Scenario | Monthly Cost (USD) | Daily Cost (USD) |
|----------|-------------------|-----------------|
| Normal operation (2 ASG + 1 bastion) | ~$78.34 | ~$2.61 |
| Peak load (4 ASG + 1 bastion) | ~$93.53 | ~$3.12 |

**Largest cost driver:** NAT Gateway ($32.85/month — 42% of normal monthly cost)

### Comparison with terraform-main

| Variant | Normal Monthly | Normal Daily | Difference |
|---------|---------------|--------------|------------|
| terraform-main | ~$71.30 | ~$2.38 | — |
| terraform-students | ~$78.34 | ~$2.61 | +$7.04/month |

The cost difference is due to the always-on bastion host ($7.59/month) in the student variant, which replaces the near-zero-cost EC2 Instance Connect Endpoint used in terraform-main.

## Notes

- **SNS Notifications:** Email notifications have no additional cost for the first 1,000 emails per month.
- **CloudWatch:** No custom CloudWatch alarms are created. The Target Tracking scaling policy manages its own internal alarms automatically at no additional cost.
- **Variability Disclaimer:** Actual costs may vary based on traffic volume, scaling events, data transfer patterns, and AWS pricing changes. Estimates assume On-Demand pricing without free-tier discounts.
- **Recommendation:** Use [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/) or [AWS Pricing Calculator](https://calculator.aws/) for precise estimates tailored to your specific usage patterns.
