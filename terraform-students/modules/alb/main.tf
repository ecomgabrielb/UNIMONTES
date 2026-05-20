###############################################################################
# Application Load Balancer (Student Variant - HTTP Only)
# Internet-facing ALB deployed across ALB_Layer subnets with cross-zone
# load balancing enabled. No HTTPS listener or ACM certificate required.
###############################################################################

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.alb_subnet_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

###############################################################################
# Target Group
# HTTP on port 80 with health checks: path /, interval 6s, timeout 5s,
# healthy/unhealthy thresholds of 2.
###############################################################################

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 6
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

###############################################################################
# HTTP Listener (port 80)
# Forwards traffic directly to the target group. No HTTPS redirect since
# the student variant does not use ACM certificates or custom domains.
###############################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}
