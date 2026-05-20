# Terraform Deployment Guide (terraform-students)

This guide provides step-by-step instructions to deploy the resilient web server infrastructure using Terraform. The `terraform-students/` configuration deploys a simplified variant that works without a custom domain — you access the application directly via the ALB DNS name on HTTP (port 80).

**Key differences from terraform-main:**
- No custom domain, Route 53, ACM certificate, or CloudFront
- HTTP-only ALB (no HTTPS)
- Each student deploys independently in their own AWS account
- S3 bucket name includes your AWS Account ID for global uniqueness

---

## 1. Prerequisites

Before starting, ensure the following tools are installed and configured:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Terraform CLI | >= 1.0 | Infrastructure provisioning |
| AWS CLI | v2 | AWS credential management and CloudFormation bootstrap |
| Git | Any recent version | Clone the repository |

### Install Terraform CLI

- **Windows**: Download from https://developer.hashicorp.com/terraform/downloads and add to PATH
- **Linux/macOS**: Use package manager or download binary

Verify installation:

```bash
terraform --version
```

### Install AWS CLI v2

- **Windows**: Download MSI installer from https://aws.amazon.com/cli/
- **Linux**: `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install`
- **macOS**: `brew install awscli`

Verify installation:

```bash
aws --version
```

### AWS IAM Permissions

Your IAM user must have permissions to create and manage the following services:

- VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables
- EC2 (instances, launch templates, security groups, key pairs, EIPs)
- Elastic Load Balancing (ALB, target groups, listeners)
- Auto Scaling (groups, policies)
- S3 (for Terraform state)
- DynamoDB (for state locking)
- CloudWatch (metrics)
- SNS (topics, subscriptions)
- SSM Parameter Store (for bastion private key)
- CloudFormation (for bootstrap stack)

> **Tip**: For a demo/lab environment, the `AdministratorAccess` managed policy simplifies setup. For production, use least-privilege policies.

---

## 2. AWS Credential Configuration

Configure your AWS credentials using one of the following methods:

### Option A: AWS CLI Configure (Recommended)

```bash
aws configure
```

Enter the following when prompted:

```
AWS Access Key ID [None]: <YOUR_ACCESS_KEY_ID>
AWS Secret Access Key [None]: <YOUR_SECRET_ACCESS_KEY>
Default region name [None]: us-east-1
Default output format [None]: json
```

### Option B: Environment Variables

**Linux/macOS:**

```bash
export AWS_ACCESS_KEY_ID="<YOUR_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_ACCESS_KEY>"
export AWS_DEFAULT_REGION="us-east-1"
```

**Windows (PowerShell):**

```powershell
$env:AWS_ACCESS_KEY_ID = "<YOUR_ACCESS_KEY_ID>"
$env:AWS_SECRET_ACCESS_KEY = "<YOUR_SECRET_ACCESS_KEY>"
$env:AWS_DEFAULT_REGION = "us-east-1"
```

**Windows (CMD):**

```cmd
set AWS_ACCESS_KEY_ID=<YOUR_ACCESS_KEY_ID>
set AWS_SECRET_ACCESS_KEY=<YOUR_SECRET_ACCESS_KEY>
set AWS_DEFAULT_REGION=us-east-1
```

### Verify Credentials

```bash
aws sts get-caller-identity
```

Expected output (your account ID and ARN):

```json
{
    "UserId": "AIDAEXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

> **Important**: Note your AWS Account ID from the output above — you will need it in subsequent steps.

---

## 3. Bootstrap Stack Deployment

The bootstrap stack creates the S3 bucket and DynamoDB table required for Terraform remote state. The S3 bucket name automatically includes your AWS Account ID for global uniqueness, so each student can deploy independently.

### 3.1 Navigate to the CloudFormation Directory

From the repository root:

```bash
cd cloudformation/
```

> **Note**: The `cloudformation/` folder is at the repository root (shared by both `terraform-main` and `terraform-students`).

### 3.2 Deploy the Bootstrap Stack

```bash
aws cloudformation create-stack \
  --stack-name resilient-web-server-bootstrap \
  --template-body file://bootstrap.yaml
```

**Windows (PowerShell):**

```powershell
aws cloudformation create-stack `
  --stack-name resilient-web-server-bootstrap `
  --template-body file://bootstrap.yaml
```

### 3.3 Wait for Stack Creation to Complete

```bash
aws cloudformation wait stack-create-complete --stack-name resilient-web-server-bootstrap
```

This command blocks until the stack reaches `CREATE_COMPLETE` status (typically 1-2 minutes).

### 3.4 Retrieve Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name resilient-web-server-bootstrap \
  --query "Stacks[0].Outputs"
```

Expected output:

```json
[
    {
        "OutputKey": "StateBucketName",
        "OutputValue": "resilient-web-server-tf-state-123456789012",
        "Description": "S3 bucket name for Terraform remote state (includes account ID postfix for per-student uniqueness)"
    },
    {
        "OutputKey": "StateBucketArn",
        "OutputValue": "arn:aws:s3:::resilient-web-server-tf-state-123456789012",
        "Description": "ARN of the S3 bucket for Terraform remote state"
    },
    {
        "OutputKey": "LockTableName",
        "OutputValue": "resilient-web-server-tf-locks",
        "Description": "DynamoDB table name for Terraform state locking"
    },
    {
        "OutputKey": "LockTableArn",
        "OutputValue": "arn:aws:dynamodb:us-east-1:123456789012:table/resilient-web-server-tf-locks",
        "Description": "ARN of the DynamoDB table for Terraform state locking"
    }
]
```

> **Note**: The S3 bucket name includes your AWS Account ID (e.g., `resilient-web-server-tf-state-123456789012`). You will need this value in the next step.

---

## 4. Terraform Init

### 4.1 Navigate to the terraform-students Directory

```bash
cd terraform-students/
```

### 4.2 Update backend.tf with Your Account ID

Open `backend.tf` and replace `<AWS_ACCOUNT_ID>` with your actual AWS Account ID:

**Before:**

```hcl
terraform {
  backend "s3" {
    bucket         = "resilient-web-server-tf-state-<AWS_ACCOUNT_ID>"
    key            = "terraform-students/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "resilient-web-server-tf-locks"
  }
}
```

**After (example with account ID 123456789012):**

```hcl
terraform {
  backend "s3" {
    bucket         = "resilient-web-server-tf-state-123456789012"
    key            = "terraform-students/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "resilient-web-server-tf-locks"
  }
}
```

### 4.3 Initialize Terraform

```bash
terraform init
```

Expected output:

```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Finding hashicorp/tls versions matching "~> 4.0"...
- Installing hashicorp/aws v5.x.x...
- Installing hashicorp/tls v4.x.x...
- Installed hashicorp/aws v5.x.x (signed by HashiCorp)
- Installed hashicorp/tls v4.x.x (signed by HashiCorp)

Terraform has been successfully initialized!
```

> **Troubleshooting**: If you see "Error configuring S3 Backend", verify that:
> - The bootstrap stack deployed successfully
> - The bucket name in `backend.tf` matches the `StateBucketName` output exactly (including your account ID)
> - Your AWS credentials have permission to access the S3 bucket and DynamoDB table

---

## 5. Terraform Plan

### 5.1 Create terraform.tfvars

Copy the example file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Windows (PowerShell):**

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### 5.2 Update terraform.tfvars

Edit `terraform.tfvars` and set the `alarm_notification_email` to your email address:

```hcl
# Project Configuration
project_name = "resilient-web-server"
aws_region   = "us-east-1"

# Network
vpc_cidr = "10.0.0.0/24"

# Compute
instance_type = "t3.micro"

# Monitoring (required - no default)
alarm_notification_email = "your-email@example.com"

# Auto Scaling Group
asg_min     = 2
asg_max     = 4
asg_desired = 2
```

> **Important**: Replace `your-email@example.com` with a real email address. You will receive a confirmation email from AWS SNS after deployment.

### 5.3 Run Terraform Plan

```bash
terraform plan
```

Review the planned resources. You should see approximately 25-30 resources to be created, including:

- VPC, subnets, route tables, Internet Gateway, NAT Gateway
- Security groups (ALB, APP, Bastion)
- Bastion host (EC2 instance, TLS key pair, AWS key pair, SSM parameter)
- ALB, HTTP listener, target group
- Launch template, Auto Scaling Group, Target Tracking scaling policy
- SNS topic, ASG notifications

> **Note**: If `terraform plan` reports errors about missing variables or configuration issues, fix them before proceeding. Terraform will not create any resources until `terraform apply` is explicitly run.

---

## 6. Terraform Apply

### 6.1 Apply the Configuration

```bash
terraform apply
```

Terraform will display the execution plan and prompt for confirmation:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Type `yes` and press Enter.

### 6.2 Wait for Completion

The deployment typically takes **4-6 minutes** due to:

- **NAT Gateway**: Provisioning takes ~2-3 minutes
- **Bastion host**: Instance launch takes ~1-2 minutes
- **ASG instances**: Launch and health check registration takes ~2-3 minutes

### 6.3 Review Outputs

After successful completion, Terraform displays the outputs:

```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name             = "resilient-web-server-alb-123456789.us-east-1.elb.amazonaws.com"
bastion_public_ip        = "54.123.45.67"
ssm_private_key_parameter = "/resilient-web-server/bastion-private-key"
vpc_id                   = "vpc-0abc123def456789"
```

> **Save the ALB DNS name** — this is the URL you will use to access your application.
>
> **Bastion access:** Use the `bastion_public_ip` to SSH into the bastion host. Retrieve the private key from SSM Parameter Store using the `ssm_private_key_parameter` path.

---

## 7. Verification

### 7.1 Test ALB via HTTP

Test that the ALB is responding:

**Linux/macOS:**

```bash
curl http://$(terraform output -raw alb_dns_name)
```

**Windows (PowerShell):**

```powershell
$alb = terraform output -raw alb_dns_name
Invoke-WebRequest -Uri "http://$alb"
```

**Expected response**: HTTP 200 OK with the Apache HTTPD page content showing instance ID and Availability Zone.

```html
<h1>Hello AWS pros</h1>
<p>Instance ID: i-0abc123def456789</p>
<p>Availability Zone: us-east-1a</p>
```

### 7.2 Verify Multiple Instances

Refresh the page several times (or run curl multiple times). You should see two different instance IDs alternating, confirming the ALB is distributing traffic across both AZs.

```bash
# Run multiple times to see different instances
curl http://$(terraform output -raw alb_dns_name)
curl http://$(terraform output -raw alb_dns_name)
```

### 7.3 Confirm SNS Email Subscription

After deployment, AWS sends a confirmation email to the address specified in `alarm_notification_email`. Check your inbox (and spam folder) for an email from `AWS Notifications` with subject "AWS Notification - Subscription Confirmation".

Click the **Confirm subscription** link in the email to activate ASG scaling notifications (you will receive emails when instances are launched or terminated).

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `terraform init` fails with S3 backend error | Verify bootstrap stack is deployed and bucket name matches (including your account ID) |
| ALB returns 503 Service Unavailable | No healthy targets; check ASG instances are running and passing health checks |
| SNS confirmation email not received | Check spam folder; verify email address in `terraform.tfvars` is correct |
| `terraform apply` times out | Some resources (NAT Gateway) take several minutes; re-run `terraform apply` to continue |
| State lock error | Another `terraform` process may be running; use `terraform force-unlock <LOCK_ID>` if stuck |
| Cannot access ALB DNS name | Wait 2-3 minutes for instances to pass health checks; verify security groups allow port 80 |
| Cannot SSH to bastion | Verify bastion security group allows SSH from your IP; check the bastion instance is running |
