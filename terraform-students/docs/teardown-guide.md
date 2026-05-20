# Infrastructure Teardown Guide — Student Variant

This guide provides complete instructions to destroy all provisioned resources for the student variant of the Resilient Web Server infrastructure. Follow these steps to avoid ongoing AWS charges after the demonstration.

> **Important**: Always perform Terraform destroy before manual cleanup. If Terraform state is intact, `terraform destroy` handles most resources automatically.

---

## Table of Contents

1. [Terraform Destroy](#1-terraform-destroy)
2. [Bootstrap Stack Removal](#2-bootstrap-stack-removal)
3. [Manual Console Deletion (Reverse Dependency Order)](#3-manual-console-deletion-reverse-dependency-order)
4. [Dependency Error Handling](#4-dependency-error-handling)
5. [Zero-Resource Verification Checklist](#5-zero-resource-verification-checklist)

---

## 1. Terraform Destroy

Use this method when the Terraform state is intact and you deployed via `terraform apply`.

### Steps

1. **Navigate to the terraform-students directory:**

   ```bash
   cd terraform-students/
   ```

2. **Run terraform destroy:**

   ```bash
   terraform destroy
   ```

3. **Review the destruction plan.** Terraform will display all resources to be destroyed. Confirm by typing:

   ```
   yes
   ```

4. **Wait for completion.** The destroy process may take several minutes (NAT Gateway takes the longest).

5. **Verify successful destruction:**

   ```bash
   terraform show
   ```

   Expected output: `No state.` (or empty state with no resources listed)

### Notes

- If `terraform destroy` fails partway through, run it again. Terraform is idempotent and will continue from where it left off.
- If the state file is corrupted or missing, you must delete resources manually (see Section 3).

---

## 2. Bootstrap Stack Removal

After Terraform destroy completes successfully, remove the CloudFormation bootstrap stack that holds the S3 state bucket and DynamoDB lock table.

### Steps

1. **Empty the S3 state bucket** (S3 buckets must be empty before deletion):

   ```bash
   aws s3 rm s3://resilient-web-server-tf-state-<ACCOUNT_ID> --recursive
   ```

   Replace `<ACCOUNT_ID>` with your AWS account ID.

2. **Delete the CloudFormation stack:**

   ```bash
   aws cloudformation delete-stack --stack-name resilient-web-server-bootstrap
   ```

3. **Wait for stack deletion to complete:**

   ```bash
   aws cloudformation wait stack-delete-complete --stack-name resilient-web-server-bootstrap
   ```

4. **Verify the stack is deleted:**

   ```bash
   aws cloudformation describe-stacks --stack-name resilient-web-server-bootstrap
   ```

   Expected output: An error stating the stack does not exist, or the stack no longer appears in the CloudFormation console.

### Notes

- If the S3 bucket has versioning enabled, you must also delete all object versions before the bucket can be removed. Use:
  ```bash
  aws s3api delete-objects --bucket resilient-web-server-tf-state-<ACCOUNT_ID> --delete "$(aws s3api list-object-versions --bucket resilient-web-server-tf-state-<ACCOUNT_ID> --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
  ```
- The DynamoDB table is deleted automatically as part of the CloudFormation stack.

---

## 3. Manual Console Deletion (Reverse Dependency Order)

Use this method when Terraform state is lost or corrupted, or when resources were created manually via the AWS Console. Delete resources in reverse dependency order to avoid dependency errors.

### Deletion Order

#### 3.1 Delete SNS Topic and Subscriptions

1. Navigate to **SNS → Topics**
2. Select the project SNS topic
3. Delete all subscriptions first: click the topic → **Subscriptions** tab → select all → **Delete**
4. Return to Topics, select the topic → **Delete**
5. Confirm deletion

#### 3.2 Delete Auto Scaling Group

1. Navigate to **EC2 → Auto Scaling Groups**
2. Select the project ASG
3. Edit the ASG: set **Desired capacity** to 0, **Minimum capacity** to 0
4. Wait for all instances to terminate (check **EC2 → Instances**)
5. Once all instances are terminated, select the ASG → **Delete**
6. Confirm deletion

#### 3.3 Delete Launch Template

1. Navigate to **EC2 → Launch Templates**
2. Select the project launch template
3. Click **Actions → Delete template**
4. Type "Delete" to confirm

#### 3.4 Delete ALB and Listeners

1. Navigate to **EC2 → Load Balancers**
2. Select the project ALB
3. Click **Actions → Delete load balancer**
4. Type "confirm" to delete

> Listeners are automatically deleted with the load balancer.

#### 3.5 Delete Target Group

1. Navigate to **EC2 → Target Groups**
2. Select the project target group
3. Click **Actions → Delete**
4. Confirm deletion

#### 3.6 Terminate Bastion Instance

1. Navigate to **EC2 → Instances**
2. Select the bastion instance (`bastion-resilient-web-server`)
3. Click **Instance state → Terminate instance**
4. Confirm termination
5. Wait for the instance state to show **Terminated**

#### 3.7 Delete Key Pair

1. Navigate to **EC2 → Key Pairs**
2. Select the project key pair (`resilient-web-server-bastion-key`)
3. Click **Actions → Delete**
4. Confirm deletion

#### 3.8 Delete NAT Gateway

1. Navigate to **VPC → NAT Gateways**
2. Select the project NAT Gateway
3. Click **Actions → Delete NAT gateway**
4. Type "delete" to confirm
5. **Wait for the state to change to "Deleted"** (this may take 1-2 minutes). Do NOT proceed to release the Elastic IP until the NAT Gateway shows "Deleted" state.

#### 3.9 Release Elastic IP

1. Navigate to **VPC → Elastic IPs**
2. Select the Elastic IP that was associated with the NAT Gateway
3. Click **Actions → Release Elastic IP address**
4. Confirm release

> **Note**: The Elastic IP cannot be released while still associated with the NAT Gateway. Wait for the NAT Gateway to reach "Deleted" state first.

#### 3.10 Delete Security Groups

Delete in this order to avoid dependency errors:

1. **Bastion Security Group** — Navigate to **VPC → Security Groups**, select the Bastion SG → **Delete**
2. **APP Security Group** — Select the APP SG → **Delete**
3. **ALB Security Group** — Select the ALB SG → **Delete**

> **Note**: The default VPC security group cannot be deleted and should be left as-is.

#### 3.11 Delete Subnets

1. Navigate to **VPC → Subnets**
2. Select all 5 project subnets (2 ALB_Layer, 2 APP_Layer, 1 Services)
3. Click **Actions → Delete subnet**
4. Confirm deletion

#### 3.12 Delete Route Tables

1. Navigate to **VPC → Route Tables**
2. Select the **private route table** (routes to NAT Gateway) → **Delete**
3. Select the **public route table** (routes to IGW) → **Delete**

> **Note**: The main (default) route table is deleted automatically with the VPC. Only delete explicitly created route tables.

#### 3.13 Detach and Delete Internet Gateway

1. Navigate to **VPC → Internet Gateways**
2. Select the project IGW
3. Click **Actions → Detach from VPC**
4. Confirm detachment
5. Select the IGW again → **Actions → Delete internet gateway**
6. Confirm deletion

#### 3.14 Delete VPC

1. Navigate to **VPC → Your VPCs**
2. Select the project VPC (not the default VPC)
3. Click **Actions → Delete VPC**
4. Confirm deletion

> **Note**: If VPC deletion fails, there are still dependent resources. Check Sections 3.12-3.15 and the Dependency Error Handling section below.

---

## 4. Dependency Error Handling

If resource deletion fails, use the following troubleshooting steps.

### VPC Deletion Fails

**Symptom**: Error message stating the VPC has dependencies.

**Resolution**:
1. Check for remaining **ENIs** (Elastic Network Interfaces): **VPC → Network Interfaces** — filter by VPC ID. Delete or detach any remaining ENIs.
2. Check for remaining **Security Groups**: **VPC → Security Groups** — filter by VPC ID. Delete all non-default security groups.
3. Check for remaining **Subnets**: **VPC → Subnets** — filter by VPC ID. Delete all subnets.
4. Check for remaining **Internet Gateways**: Detach and delete any attached IGWs.
5. Check for remaining **NAT Gateways**: Delete and wait for "Deleted" state.
6. Check for remaining **VPC Endpoints**: Delete any remaining endpoints.
7. Retry VPC deletion after clearing all dependencies.

### Security Group Deletion Fails

**Symptom**: Error stating the security group is referenced by another resource.

**Resolution**:
1. Check for **cross-references** between security groups: A security group rule may reference the SG you are trying to delete. Remove the referencing rule first.
2. Check for **ENIs** using the security group: **VPC → Network Interfaces** — filter by security group. Delete or modify the ENI's security group assignment.
3. Check for **Load Balancers** or **bastion instance** still using the SG.
4. Delete in the correct order: Bastion SG → APP SG → ALB SG.

### NAT Gateway Deletion Fails or EIP Release Fails

**Symptom**: Cannot release Elastic IP; error states it is still associated.

**Resolution**:
1. Verify the NAT Gateway state is **"Deleted"** (not "Deleting" or "Available").
2. Wait 1-2 minutes for the NAT Gateway to fully transition to "Deleted" state.
3. Once the NAT Gateway shows "Deleted", retry releasing the Elastic IP.
4. If the EIP still cannot be released, disassociate it manually:
   ```bash
   aws ec2 disassociate-address --association-id <association-id>
   aws ec2 release-address --allocation-id <allocation-id>
   ```

### ALB Deletion Fails

**Symptom**: Error stating the ALB has active listeners or dependencies.

**Resolution**:
1. Delete all **listeners** first: **EC2 → Load Balancers** → select ALB → **Listeners** tab → delete each listener.
2. Ensure no **target groups** reference the ALB (target groups can exist independently but may block deletion if actively associated).
3. Retry ALB deletion after removing listeners.

---

## 5. Zero-Resource Verification Checklist

After completing all teardown steps, verify that no project resources remain by checking each AWS service dashboard.

| # | Service / Dashboard | What to Verify | Expected State |
|---|---|---|---|
| 1 | **EC2 → Instances** | No running instances from this project | 0 running instances (or only unrelated instances) |
| 2 | **VPC → Your VPCs** | No custom project VPC | Only the default VPC remains |
| 3 | **EC2 → Load Balancers** | No project ALB | No load balancers listed (or only unrelated) |
| 4 | **EC2 → Auto Scaling Groups** | No project ASG | No auto scaling groups listed |
| 5 | **SNS → Topics** | No project topics | No topics listed |
| 6 | **S3** | No Terraform state bucket | No `resilient-web-server-tf-state-*` bucket |
| 7 | **DynamoDB → Tables** | No Terraform lock table | No `resilient-web-server-tf-locks` table |
| 8 | **VPC → Elastic IPs** | No orphaned Elastic IPs | No unassociated Elastic IPs from this project |
| 9 | **VPC → NAT Gateways** | No project NAT Gateways | All show "Deleted" or none listed |
| 10 | **VPC → Internet Gateways** | No project IGW | Only default VPC IGW (if any) |
| 11 | **AWS Billing Console** | No unexpected charges accumulating | Verify charges have stopped or are decreasing |

### Final Verification Commands (CLI)

Run these commands to confirm no resources remain:

```bash
# Check for running EC2 instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key=='Name']|[0].Value}" --output table

# Check for load balancers
aws elbv2 describe-load-balancers --query "LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName}" --output table

# Check for auto scaling groups
aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[].AutoScalingGroupName" --output table

# Check for NAT Gateways (exclude "Deleted" state)
aws ec2 describe-nat-gateways --filter "Name=state,Values=available,pending" --query "NatGateways[].{ID:NatGatewayId,State:State}" --output table

# Check for non-default VPCs
aws ec2 describe-vpcs --filters "Name=is-default,Values=false" --query "Vpcs[].{ID:VpcId,CIDR:CidrBlock}" --output table

# Check S3 for state bucket
aws s3 ls | grep "resilient-web-server"

# Check DynamoDB for lock table
aws dynamodb list-tables --query "TableNames" --output table
```

If all checks return empty results (or only show unrelated resources), the teardown is complete.

---

## Summary

| Method | When to Use |
|--------|-------------|
| **Terraform Destroy** (Section 1) | Terraform state is intact; primary method |
| **Bootstrap Stack Removal** (Section 2) | After Terraform destroy; removes state infrastructure |
| **Manual Console Deletion** (Section 3) | State is lost/corrupted, or resources were created manually |
| **Dependency Error Handling** (Section 4) | When deletion fails due to resource dependencies |
| **Verification Checklist** (Section 5) | Always run after teardown to confirm zero resources |
