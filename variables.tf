# ================================================================== general ===

variable "bot_version" {

  description = "Version of the SecurityHub bot to use. Use 'latest' for the main branch or a specific version tag like 'v0.1.0'."
  type        = string
  default     = "latest"
}

variable "bot_repo" {
  description = "GitHub repository URL for the SecurityHub bot source code."
  type        = string
  default     = "https://github.com/cruxstack/aws-securityhubv2-bot.git"
}

variable "bot_force_rebuild_id" {
  description = "ID to force rebuilding the Lambda function source code. Increment this value to trigger a rebuild."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------- lambda ---

variable "lambda_config" {
  description = "Configuration for the SecurityHub bot Lambda function."
  type = object({
    memory_size                    = optional(number, 256)
    timeout                        = optional(number, 60)
    runtime                        = optional(string, "provided.al2023")
    architecture                   = optional(string, "x86_64")
    reserved_concurrent_executions = optional(number, -1)
  })
  default = {}

  validation {
    condition     = var.lambda_config.memory_size >= 128 && var.lambda_config.memory_size <= 10240
    error_message = "Lambda memory_size must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.lambda_config.timeout >= 1 && var.lambda_config.timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda function logs in CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_log_retention_days)
    error_message = "Lambda log retention days must be a valid CloudWatch Logs retention period."
  }
}

# ------------------------------------------------------------------- rules ---

variable "rules" {
  description = "List of automation rules for Security Hub findings. Each rule defines filters, actions, and notification settings."
  type = list(object({
    name    = string
    enabled = bool
    filters = object({
      finding_types  = optional(list(string))
      severity       = optional(list(string))
      product_name   = optional(list(string))
      resource_types = optional(list(string))
      resource_tags = optional(list(object({
        name  = string
        value = string
      })))
      accounts = optional(list(string))
      regions  = optional(list(string))
    })
    action = object({
      status_id = number
      comment   = string
    })
    skip_notification = optional(bool, false)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.rules : contains([0, 1, 2, 3, 4, 5, 6, 99], rule.action.status_id)
    ])
    error_message = "Rule action status_id must be a valid OCSF status (0-6, 99): 0=Unknown, 1=New, 2=In Progress, 3=Suppressed, 4=Resolved, 5=Archived, 6=Deleted, 99=Other."
  }

  validation {
    condition     = !var.rules_s3_bucket.enabled ? length(var.rules) == 0 || length(jsonencode(var.rules)) <= 3276 : true
    error_message = "When S3 storage is disabled, the JSON-encoded rules must not exceed 3.2KB (3276 bytes) to stay within Lambda environment variable limits. Current size: ${length(jsonencode(var.rules))} bytes. Consider enabling S3 storage for larger rule sets."
  }
}

variable "rules_s3_bucket" {
  description = "S3 bucket configuration for storing automation rules. Set create=true to create a new bucket, or provide an existing bucket name."
  type = object({
    enabled = optional(bool, false)
    create  = optional(bool, true)
    name    = optional(string)
    prefix  = optional(string, "rules/")
  })
  default = {}

  validation {
    condition     = !var.rules_s3_bucket.create || var.rules_s3_bucket.enabled
    error_message = "When rules_s3_bucket.create is true, enabled must also be true."
  }
}

# ------------------------------------------------------------------- slack ---

variable "slack_config" {
  description = "Slack integration configuration for sending notifications."
  sensitive   = true
  type = object({
    enabled = optional(bool, false)
    token   = optional(string, "")
    channel = optional(string, "")
  })
  default = {}

  validation {
    condition     = !var.slack_config.enabled || (var.slack_config.token != null && var.slack_config.channel != null)
    error_message = "When slack_config.enabled is true, both token and channel must be specified."
  }
}

# ----------------------------------------------------------------- console ---

variable "aws_console_config" {
  description = "AWS Console URL configuration for generating finding links."
  type = object({
    base_url           = optional(string, "https://console.aws.amazon.com")
    access_portal_url  = optional(string, "")
    access_role_name   = optional(string, "")
    securityhub_region = optional(string, "")
  })
  default = {}
}

variable "debug_enabled" {
  description = "Enable debug logging in the Lambda function."
  type        = bool
  default     = false
}

variable "eventbridge_rule_config" {
  description = "Configuration for the EventBridge rule that triggers the Lambda function."
  type = object({
    enabled       = optional(bool, true)
    event_pattern = any
  })
  default = {
    event_pattern = {
      source      = ["aws.securityhub"]
      detail-type = ["Findings Imported V2"]
    }
  }
}

