# CloudWatch Module - Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = aws_sns_topic.alarm_notifications.arn
}
