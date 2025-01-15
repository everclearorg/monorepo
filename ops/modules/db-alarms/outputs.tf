output "free_storage_space_threshold_alarm_id" {
  value = aws_cloudwatch_metric_alarm.free_storage_space_too_low[0].alarm_name
}

output "cpu_utilization_threshold_alarm_id" {
  value = aws_cloudwatch_metric_alarm.cpu_utilization_too_high[0].alarm_name
}

output "transaction_logs_disk_usage_alarm_id" {
  value = aws_cloudwatch_metric_alarm.transaction_logs_disk_usage[0].alarm_name
}
