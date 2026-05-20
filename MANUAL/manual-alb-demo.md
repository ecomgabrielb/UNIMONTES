# Manual ALB Demo — Two-Tier VPC with Load Balancer Failover

This guide walks you through creating a simple two-tier VPC with an ALB and two web servers, then simulating a node failure to demonstrate ALB failover. All steps are performed via the AWS Management Console.

**Estimated time: ~20 minutes**

---

## What You'll Build

- VPC with public and private subnets across 2 AZs (using VPC wizard)
- 2 EC2 web servers (one per AZ, private subnets)
- 1 Application Load Balancer (public subnets)
- NAT Gateway for instance internet access (package installs)

## What You'll Demonstrate

1. ALB distributes traffic across both web servers (different instance IDs on each refresh)
2. Terminate one web server → ALB routes all traffic to the surviving instance (zero downtime)

---

## Part 1: Create the Infrastructure

### 1.1 Create VPC Using the Wizard

1. Navigate to **VPC Dashboard → Create VPC**
2. Select **VPC and more**
3. Configure:
   - **Name tag auto-generation**: `alb-demo`
   - **IPv4 CIDR block**: `10.0.0.0/24`
   - **Number of Availability Zones**: `2`
   - **Number of public subnets**: `2`
   - **Number of private subnets**: `2`
   - **NAT gateways**: `In 1 AZ`
   - **VPC endpoints**: None
4. Click **Create VPC**
5. Wait for all resources to be created (~2-3 minutes)

> **Result**: The wizard creates the VPC, 4 subnets (2 public, 2 private), Internet Gateway, NAT Gateway, Elastic IP, and route tables — all wired together automatically.

### 1.2 Create Security Groups

Navigate to **VPC Dashboard → Security Groups → Create security group**.

**ALB Security Group:**
1. Name: `alb-demo-alb-sg`
2. Description: Allow HTTP from internet
3. VPC: Select `alb-demo-vpc`
4. Inbound rules: HTTP (80) from `0.0.0.0/0`
5. Outbound: All traffic (default)
6. Click **Create security group**

**Web Server Security Group:**
1. Name: `alb-demo-web-sg`
2. Description: Allow HTTP from ALB only
3. VPC: Select `alb-demo-vpc`
4. Inbound rules: HTTP (80) from `alb-demo-alb-sg` (select the ALB SG as source)
5. Outbound: All traffic (default)
6. Click **Create security group**

### 1.3 Create Target Group

1. **EC2 Dashboard → Target Groups → Create target group**
2. Target type: **Instances**
3. Name: `alb-demo-tg`
4. Protocol: HTTP, Port: 80
5. VPC: Select `alb-demo-vpc`
6. Health check path: `/`
7. Advanced health check settings: Interval `6s`, Timeout `5s`, Healthy/Unhealthy threshold `2`
8. Click **Next** → Do NOT register targets yet → **Create target group**

### 1.4 Launch EC2 Instances (2 web servers)

Navigate to **EC2 Dashboard → Instances → Launch instances**.

**Instance 1 (AZ-A):**
1. Name: `alb-demo-web-az1`
2. AMI: Amazon Linux 2023
3. Instance type: `t3.micro`
4. Key pair: Proceed without a key pair
5. Network settings:
   - VPC: `alb-demo-vpc`
   - Subnet: Select the **private subnet in AZ-A** (e.g., `alb-demo-subnet-private1-us-east-1a`)
   - Auto-assign public IP: Disable
   - Security group: Select existing → `alb-demo-web-sg`
6. Advanced details → User data — paste:

```bash
#!/bin/bash
yum update -y
yum install -y httpd

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<EOF
<h1>Hello AWS pros</h1>
<p>Instance ID: ${INSTANCE_ID}</p>
<p>Availability Zone: ${AZ}</p>
EOF

systemctl start httpd
systemctl enable httpd
```

7. Click **Launch instance**

**Instance 2 (AZ-B):**
- Repeat the same steps but:
  - Name: `alb-demo-web-az2`
  - Subnet: Select the **private subnet in AZ-B** (e.g., `alb-demo-subnet-private2-us-east-1b`)
  - Same User data script (it auto-detects instance ID and AZ)

### 1.5 Register Instances in Target Group

1. Navigate to **EC2 → Target Groups → `alb-demo-tg`**
2. Click **Register targets**
3. Select both instances (`alb-demo-web-az1` and `alb-demo-web-az2`)
4. Click **Include as pending below** → **Register pending targets**
5. Wait for both targets to show **healthy** (~30-60 seconds)

### 1.6 Create Application Load Balancer

1. **EC2 Dashboard → Load Balancers → Create Load Balancer**
2. Select **Application Load Balancer**
3. Name: `alb-demo-alb`
4. Scheme: Internet-facing
5. Network mapping:
   - VPC: `alb-demo-vpc`
   - Select both AZs → pick the **public subnets** (e.g., `alb-demo-subnet-public1-us-east-1a` and `alb-demo-subnet-public2-us-east-1b`)
6. Security groups: Remove default, select `alb-demo-alb-sg`
7. Listener: HTTP:80 → Forward to `alb-demo-tg`
8. Click **Create load balancer**
9. Wait for state **Active** (~2-3 min)

### 1.7 Verify

1. Copy the ALB DNS name from the Load Balancer details
2. Open `http://<ALB_DNS_NAME>` in your browser
3. Refresh multiple times — you should see **two different instance IDs** alternating, confirming the ALB is distributing traffic across both AZs

---

## Part 2: Simulate Node Failure

### Steps

1. Navigate to **EC2 → Instances**
2. Select `alb-demo-web-az1` → **Instance state → Terminate instance** → Confirm
3. Immediately go back to your browser and keep refreshing `http://<ALB_DNS_NAME>`

### What Happens

| Time | Event |
|------|-------|
| **0s** | Instance terminated |
| **~12s** | ALB detects unhealthy target (2 failed health checks × 6s interval) |
| **~12s** | ALB stops routing traffic to terminated instance |
| **~12s+** | All requests go to the surviving instance in AZ-B |

### What to Observe

- **Browser**: Page always loads — no errors, no downtime
- **Instance ID**: Only shows the AZ-B instance ID now (no more alternating)
- **Target Group → Targets**: One target shows `unhealthy` or `draining`, one shows `healthy`

### Key Takeaway

> "The ALB detected the failure within 12 seconds and automatically routed all traffic to the healthy instance. Users experienced zero downtime."

---

## Part 3: Clean Up (Delete All Resources)

Delete resources in this order to avoid dependency errors.

| # | Resource | Where | Action |
|---|----------|-------|--------|
| 1 | ALB | EC2 → Load Balancers | Delete |
| 2 | Target Group | EC2 → Target Groups | Delete |
| 3 | EC2 Instances | EC2 → Instances | Terminate remaining instance (wait for terminated state) |
| 4 | Security Groups | VPC → Security Groups | Delete `alb-demo-web-sg` first, then `alb-demo-alb-sg` |
| 5 | NAT Gateway | VPC → NAT Gateways | Delete (wait ~2 min for "Deleted" state) |
| 6 | Elastic IP | VPC → Elastic IPs | Release the EIP that was associated with the NAT Gateway |
| 7 | VPC | VPC → Your VPCs | Select `alb-demo-vpc` → **Actions → Delete VPC** |

> **Note**: The "Delete VPC" action will automatically delete the subnets, route tables, and Internet Gateway that were created by the wizard. You must manually delete the NAT Gateway and Elastic IP first — the VPC cannot be deleted while they exist.

### Verification

- **EC2 → Instances**: No running instances with `alb-demo-` prefix
- **VPC → Your VPCs**: No `alb-demo-vpc`
- **EC2 → Load Balancers**: No `alb-demo-alb`
- **VPC → Elastic IPs**: No orphaned EIPs

> **Tip**: If VPC deletion fails, wait 1-2 minutes for the NAT Gateway to fully release, then retry.
