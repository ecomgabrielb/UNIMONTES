# ASG Module - Auto Scaling Group with Launch Template and Scaling Policies
# Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.1, 4.2, 4.3, 4.4, 4.5

# ------------------------------------------------------------------------------
# Data Source: Amazon Linux 2023 AMI
# ------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ------------------------------------------------------------------------------
# Launch Template
# ------------------------------------------------------------------------------
resource "aws_launch_template" "web_server" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd stress-ng

    # Retry logic for metadata retrieval
    MAX_RETRIES=3
    RETRY_DELAY=5
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    for i in $(seq 1 $MAX_RETRIES); do
      INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
      AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
      if [ -n "$INSTANCE_ID" ] && [ -n "$AZ" ]; then
        break
      fi
      sleep $RETRY_DELAY
    done

    cat > /var/www/html/index.html <<HTMLEOF
    <h1>Hello AWS pros</h1>
    <p>Instance ID: $${INSTANCE_ID}</p>
    <p>Availability Zone: $${AZ}</p>
    HTMLEOF

    systemctl start httpd
    systemctl enable httpd
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server-${var.project_name}"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# ------------------------------------------------------------------------------
# Auto Scaling Group
# ------------------------------------------------------------------------------
resource "aws_autoscaling_group" "web_server" {
  name                      = "${var.project_name}-asg"
  min_size                  = var.asg_min
  max_size                  = var.asg_max
  desired_capacity          = var.asg_desired
  vpc_zone_identifier       = var.app_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 30
  default_cooldown          = 60

  launch_template {
    id      = aws_launch_template.web_server.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-server-${var.project_name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# Target Tracking Scaling Policy
# AWS manages scale-out and scale-in automatically to maintain 50% average CPU.
# Reacts within 1-5 minutes (depends on when the 5-min metric cycle aligns).
# ------------------------------------------------------------------------------
resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "${var.project_name}-target-tracking-cpu"
  autoscaling_group_name = aws_autoscaling_group.web_server.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }

  estimated_instance_warmup = 30
}
