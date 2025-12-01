variable "namespace" {
  description = "Namespace for resource naming"
  type        = string
  default     = "ex"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "stage" {
  description = "Stage name"
  type        = string
  default     = ""
}

variable "rules_s3_bucket" {
  description = "S3 bucket containing automation rules"
  type        = string
}

variable "slack_bot_token" {
  description = "Slack bot token (requires chat:write scope)"
  type        = string
  sensitive   = true
}

variable "slack_channel_id" {
  description = "Slack channel ID (e.g., C000XXXXXXX)"
  type        = string
}

variable "aws_access_portal_url" {
  description = "AWS SSO/Identity Center access portal URL"
  type        = string
  default     = ""
}

variable "aws_access_role_name" {
  description = "IAM role name for federated access"
  type        = string
  default     = "SecurityAuditor"
}
