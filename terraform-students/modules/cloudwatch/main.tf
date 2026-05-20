# CloudWatch Module - ASG Scaling Notifications via SNS

# ------------------------------------------------------------------------------
# SNS Topic for ASG Events
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "alarm_notifications" {
  name = "${var.project_name}-notifications"

  tags = {
    Name = "${var.project_name}-notifications"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

# ------------------------------------------------------------------------------
# ASG Scaling Notifications (Launch + Terminate events)
# Fires whenever the ASG launches or terminates an instance, regardless of cause.
# This is the only notification you need — it tells you when scaling happens.
# ------------------------------------------------------------------------------
resource "aws_autoscaling_notification" "asg_events" {
  group_names = [var.asg_name]
  topic_arn   = aws_sns_topic.alarm_notifications.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}
