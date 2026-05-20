# Stress Test & Resilience Demo Guide

This guide walks you through two demonstrations of the resilient web server infrastructure:

1. **Demo 1: AZ Failure Recovery** — Terminate an instance, watch the ASG replace it automatically
2. **Demo 2: CPU-Based Scale-Out & Scale-In** — Stress the instances, watch the ASG add capacity, then scale back down

**Total estimated demo time: ~12-15 minutes**

---

## Prerequisites

Before starting, confirm the following:

- [ ] Infrastructure is deployed (via `terraform-students` or manual console deployment)
- [ ] Auto Scaling Group is running with **2 healthy instances** (desired capacity)
- [ ] SNS email subscription is **confirmed** (check your inbox for the confirmation email from AWS)
- [ ] `stress-ng` is installed on instances (automatically installed via UserData script)
- [ ] Bastion host is running and accessible via its public IP
- [ ] Private key is copied to the bastion (`~/key.pem`)

> **CPU Credits Note:** The launch template uses `unlimited` CPU credits for t3.micro instances. This means `stress-ng` will immediately push CPU to 100% without waiting for burst credits.

---

## Demo 1: AZ Failure Recovery (~2 minutes)

This demonstrates that the system maintains availability when an instance is suddenly lost.

### Expected Email Notifications

| # | Notification | When |
|---|-------------|------|
| 1 | **EC2_INSTANCE_TERMINATE** | Immediately after you terminate the instance |
| 2 | **EC2_INSTANCE_LAUNCH** | ~30-60s later (ASG launches replacement) |

### Steps

1. Open `http://<ALB_DNS_NAME>` in a browser — refresh a few times to see two different instance IDs
2. Navigate to **EC2 → Instances**
3. Select one instance → **Instance state → Terminate instance**
4. Immediately start refreshing the browser — the page should **always load** (no errors)

### What Happens (Timeline)

| Time | Event | What to Show Students |
|------|-------|----------------------|
| **0s** | Instance terminated | Browser still works (ALB routes to surviving instance) |
| **~12s** | ALB marks target unhealthy | Target Group → Targets shows 1 healthy, 1 unhealthy |
| **~30-60s** | ASG launches replacement | ASG → Activity tab shows launch event |
| **~90s** | New instance passes health check | Target Group shows 2 healthy targets again |
| **~90s** | Browser shows 2 instance IDs again | Refresh to see both AZs serving traffic |

### Key Takeaway for Students

> "The ALB detected the failure in 12 seconds and routed all traffic to the surviving instance. The ASG detected it was below desired capacity and launched a replacement. Zero downtime."

---

## Demo 2: CPU-Based Scale-Out & Scale-In (~10-13 minutes)

This demonstrates automatic scaling based on CPU load.

### Expected Email Notifications (in order)

| # | Notification | When |
|---|-------------|------|
| 1 | **EC2_INSTANCE_LAUNCH** | ~1-5 min after stress starts (Target Tracking scales out) |
| 2 | **EC2_INSTANCE_TERMINATE** | ~5-15 min after stress stops (Target Tracking scales in) |

### Step 1: Retrieve the SSH Private Key

#### Option A: Copy from AWS Console (Recommended for Lab Environments)

1. Navigate to **AWS Systems Manager → Parameter Store**
2. Find the parameter `/<project_name>/bastion-private-key` (e.g., `/resilient-web-server/bastion-private-key`)
3. Click on the parameter → Click **Show** to reveal the value
4. Copy the entire key (from `-----BEGIN RSA PRIVATE KEY-----` to `-----END RSA PRIVATE KEY-----`)
5. Save to a file called `bastion-key.pem`

#### Option B: AWS CLI (If Permissions Allow)

```bash
aws ssm get-parameter \
  --name "/resilient-web-server/bastion-private-key" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > bastion-key.pem
chmod 400 bastion-key.pem
```

### Using PuTTY (Windows)

1. Open **PuTTYgen** → **Conversions → Import key** → select `bastion-key.pem`
2. Click **Save private key** → save as `bastion-key.ppk`
3. Open **PuTTY**:
   - Host Name: `<BASTION_PUBLIC_IP>`
   - Connection → SSH → Auth → Credentials: browse to `bastion-key.ppk`
   - Connection → Data: Auto-login username: `ec2-user`
   - Click **Open**

> **Tip**: Windows 10+ has OpenSSH built-in. You can use `ssh -i bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>` directly.

### Step 2: Get Instance Private IPs

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=web-server-resilient-web-server" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,PrivateIP:PrivateIpAddress,AZ:Placement.AvailabilityZone}" \
  --output table
```

### Step 3: Connect to Bastion and Copy Key

```bash
# SSH to bastion
ssh -i bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

If you haven't already copied the key to the bastion:

**Linux/macOS:**
```bash
scp -i bastion-key.pem bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>:~/key.pem
```

**Windows (pscp):**
```cmd
pscp -i bastion-key.ppk bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>:~/key.pem
```

Then on the bastion:
```bash
chmod 400 ~/key.pem
```

### Step 4: Run Stress Test (360 seconds)

From the bastion, stress both instances simultaneously and verify CPU:

```bash
ssh -i ~/key.pem ec2-user@<IP_1> "nohup stress-ng --cpu 0 --timeout 360 &" &
ssh -i ~/key.pem ec2-user@<IP_2> "nohup stress-ng --cpu 0 --timeout 360 &" &

# Wait a few seconds, then check CPU
sleep 5
ssh -i ~/key.pem ec2-user@<IP_1> "top -bn1 | head -5"
ssh -i ~/key.pem ec2-user@<IP_2> "top -bn1 | head -5"
```

You should see `%Cpu(s): 100.0 us` on both instances, confirming the stress test is running.

> **Why 360 seconds (6 minutes)?** AWS publishes ASG-level CPU metrics every 5 minutes. A 6-minute stress ensures at least one full metric cycle captures 100% CPU, guaranteeing Target Tracking sees the spike and triggers scale-out while stress is still running.

### Step 5: Watch It Happen (Timeline)

| Time | Event | What to Show Students |
|------|-------|----------------------|
| **0s** | Stress starts on both instances | `top` shows 100% CPU |
| **~60-300s** | Target Tracking detects avg CPU > 70% | ASG → Activity: "Launching a new EC2 instance" |
| **~60-300s** | 📧 **Email: "EC2_INSTANCE_LAUNCH"** | Show the email |
| **~120-360s** | New instance passes health check | Target Group: 3 healthy targets |
| **~120-360s** | Browser shows 3 instance IDs | Refresh ALB URL to see new instance |
| **360s** | Stress stops automatically | CPU drops to ~2% |
| **~5-15 min** | Target Tracking scales in (after sustained low CPU) | ASG → Activity: "Terminating an EC2 instance" |
| **~5-15 min** | 📧 **Email: "EC2_INSTANCE_TERMINATE"** | Show the email |
| **~10-15 min** | Back to 2 instances | Target Group: 2 healthy targets |

### Step 6: Verification

- [ ] ASG → Activity: shows launch events (scale-out) and terminate events (scale-in)
- [ ] Final state: 2 instances running (desired capacity restored)
- [ ] Emails received for EC2_INSTANCE_LAUNCH and EC2_INSTANCE_TERMINATE events

---

## Monitoring Tips During Demo

Open these in separate browser tabs before starting:

1. **EC2 → Auto Scaling Groups → Activity** — watch launch/terminate events
2. **EC2 → Auto Scaling Groups → Automatic scaling** — view Target Tracking policy status
3. **EC2 → Target Groups → Targets** — watch health status
4. **Your email inbox** — watch notifications arrive
5. **Browser tab with ALB URL** — refresh to see instance IDs change

---

## Troubleshooting

### `stress-ng` command not found

The UserData script may not have completed. From the bastion:
```bash
ssh -i ~/key.pem ec2-user@<APP_IP> "which stress-ng"
```
If missing, install manually: `sudo yum install -y stress-ng`

### Cannot SSH to bastion

1. Verify bastion SG allows inbound SSH (port 22) from 0.0.0.0/0
2. Verify key file permissions are `400`
3. Verify username is `ec2-user`
4. Verify bastion has a public IP (`terraform output bastion_public_ip`)

### Cannot SSH from bastion to APP instances

1. Verify APP SG allows inbound SSH (port 22) from bastion SG
2. Verify key exists on bastion (`ls ~/key.pem`)
3. Verify the private IP is correct

### Scale-out doesn't happen

1. Stress **both** instances — one at 100% averages to ~50% across the ASG
2. Wait at least **1-5 minutes** — Target Tracking needs a full 5-minute metric cycle to detect avg CPU > 70% target
3. Verify detailed monitoring is enabled (EC2 → Instance → Monitoring tab)
4. Check CloudWatch → Metrics → EC2 → By Auto Scaling Group for CPU data

### Scale-in doesn't happen

1. Wait **at least 5-15 minutes** after stress stops — Target Tracking is conservative on scale-in to avoid flapping
2. Verify CPU has dropped well below 70% (check CloudWatch metrics)
3. Check ASG → Activity tab for pending scaling actions

### Not receiving emails

1. Verify SNS subscription is **confirmed** (SNS → Subscriptions → Status = Confirmed)
2. Check spam/junk folder
3. Verify the email in `terraform.tfvars` is correct
