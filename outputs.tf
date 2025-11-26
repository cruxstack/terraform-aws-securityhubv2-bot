output "lambda_function_arn" {
  description = "ARN of the SecurityHub v2 bot Lambda function"
  value       = try(aws_lambda_function.this[0].arn, null)
}

output "lambda_function_name" {
  description = "Name of the SecurityHub v2 bot Lambda function"
  value       = try(aws_lambda_function.this[0].function_name, null)
}

output "lambda_function_qualified_arn" {
  description = "Qualified ARN of the SecurityHub v2 bot Lambda function"
  value       = try(aws_lambda_function.this[0].qualified_arn, null)
}

output "lambda_role_arn" {
  description = "ARN of the IAM role used by the Lambda function"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "lambda_role_name" {
  description = "Name of the IAM role used by the Lambda function"
  value       = try(aws_iam_role.this[0].name, null)
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule that triggers the Lambda function"
  value       = try(aws_cloudwatch_event_rule.securityhub[0].arn, null)
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule that triggers the Lambda function"
  value       = try(aws_cloudwatch_event_rule.securityhub[0].name, null)
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda function logs"
  value       = try(aws_cloudwatch_log_group.lambda[0].name, null)
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Lambda function logs"
  value       = try(aws_cloudwatch_log_group.lambda[0].arn, null)
}

output "rules_s3_bucket_id" {
  description = "ID of the S3 bucket for rules (if created)"
  value       = try(module.rules_s3_bucket[0].bucket_id, null)
}

output "rules_s3_bucket_arn" {
  description = "ARN of the S3 bucket for rules (if created)"
  value       = try(module.rules_s3_bucket[0].bucket_arn, null)
}
