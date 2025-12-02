module "securityhub_bot" {
  source = "../.."

  lambda_config = {
    memory_size = 512
    timeout     = 120
  }

  bot_version = "latest"

  # Define automation rules directly in Terraform
  # The module will automatically create these as objects in the S3 bucket
  rules = [
    {
      name    = "suppress-low-severity-dev"
      enabled = true
      filters = {
        severity = ["Low"]
        accounts = ["123456789012"]
      }
      action = {
        status_id = 3
        comment   = "Auto-suppressed: Low severity in dev account"
      }
      skip_notification = true
    },
    {
      name    = "suppress-informational"
      enabled = true
      filters = {
        severity = ["Informational"]
      }
      action = {
        status_id = 3
        comment   = "Auto-suppressed: Informational findings"
      }
      skip_notification = true
    }
  ]

  rules_s3_bucket = {
    enabled = true
    create  = true
    prefix  = "securityhub-rules/"
  }

  slack_config = {
    enabled = true
    token   = var.slack_bot_token
    channel = var.slack_channel_id
  }

  aws_console_config = {
    base_url           = "https://console.aws.amazon.com"
    access_portal_url  = var.aws_access_portal_url
    access_role_name   = var.aws_access_role_name
    securityhub_region = "us-east-1"
  }

  debug_enabled             = false
  lambda_log_retention_days = 90

  eventbridge_rule_config = {
    enabled = true
    # Only process Critical and High severity findings
    event_pattern = {
      source      = ["aws.securityhub"]
      detail-type = ["Findings Imported V2"]
      detail = {
        findings = {
          severity = ["Critical", "High"]
        }
      }
    }
  }

  context = module.this.context
}

module "this" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  namespace   = var.namespace
  environment = var.environment
  stage       = var.stage
  name        = "securityhub-bot"
  delimiter   = "-"

  tags = {
    Terraform = "true"
    Module    = "terraform-aws-securityhubv2-bot"
    Example   = "complete"
  }
}
