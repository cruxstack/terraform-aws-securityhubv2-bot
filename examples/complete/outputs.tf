output "lambda_function_arn" {
  description = "ARN of the SecurityHub v2 bot Lambda function"
  value       = module.securityhub_bot.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the SecurityHub v2 bot Lambda function"
  value       = module.securityhub_bot.lambda_function_name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = module.securityhub_bot.eventbridge_rule_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = module.securityhub_bot.cloudwatch_log_group_name
}
