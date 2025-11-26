# Terraform AWS SecurityHub v2 Bot

Terraform module that deploys an AWS Lambda function to automatically process
[AWS Security Hub v2 findings](https://docs.aws.amazon.com/securityhub/latest/userguide/ocsf-findings.html)
(OCSF format) with configurable automation rules and optional Slack
notifications.

## About the Bot

This Terraform module deploys the [aws-securityhubv2-bot](https://github.com/cruxstack/aws-securityhubv2-bot),
a Go-based Lambda function that automatically processes AWS Security Hub
findings in the OCSF (Open Cybersecurity Schema Framework) format. The bot can
suppress, resolve, or archive findings based on configurable rules and
optionally send notifications to Slack with rich context.

The bot is built and packaged automatically during `terraform apply` using
Docker from the source repository. You can specify a specific version or use
`latest` to deploy from the main branch.

## Features

- Automatically suppress or resolve findings based on configurable rules
  (severity, type, tags, accounts, regions)
- Store rules inline (environment variables) or in S3 for large rule sets
- Optional Slack notifications with rich context and remediation links
- Supports GuardDuty, Inspector, Macie, IAM Access Analyzer, and Security Hub
  findings
- EventBridge-triggered serverless architecture

## Usage

### Basic Example

```hcl
module "securityhub_bot" {
  source = "github.com/cruxstack/terraform-aws-securityhubv2-bot?ref=v1.0.0"

  name        = "securityhub-bot"
  bot_version = "v0.1.0"  # or "latest" for main branch

  rules = [
    {
      name    = "suppress-low-severity-dev"
      enabled = true
      filters = {
        severity = ["Low"]
        accounts = ["123456789012"]
      }
      action = {
        status_id = 3  # suppressed
        comment   = "Auto-suppressed: Low severity in dev account"
      }
      skip_notification = true
    }
  ]

  context = module.this.context
}
```

### Complete Example with Slack and S3

See the [complete example](./examples/complete) for a full configuration with
Slack notifications and S3 rule storage.

```hcl
module "securityhub_bot" {
  source = "cruxstack/securityhubv2-bot/aws"

  name        = "securityhub-bot"
  bot_version = "v0.1.0"

  rules = []

  rules_s3_bucket = {
    enabled = true
    create  = true # create s3 bucket for rules
    name    = "my-securityhub-rules"
    prefix  = "rules/"
  }

  slack_config = {
    enabled = true
    token   = var.slack_bot_token
    channel = "C000XXXXXXX"
  }

  aws_console_config = {
    access_portal_url  = "https://mycompany.awsapps.com/start"
    access_role_name   = "SecurityAuditor"
    securityhub_region = "us-east-1"
  }

  context = module.this.context
}
```

## Prerequisites

**Docker** must be installed and running on the machine executing Terraform.
The module automatically builds the Lambda function from the
[aws-securityhubv2-bot](https://github.com/cruxstack/aws-securityhubv2-bot)
repository using Docker during `terraform apply`.

## Automation Rules

See [aws-securityhubv2-bot](https://github.com/cruxstack/aws-securityhubv2-bot)
documentation for more information on rules.

### Rule Configuration

Rules are defined using the `rules` variable. For large rule sets (>3KB),
enable S3 storage:

```hcl
  rules = [{
    name    = "suppress-dev-low-severity"
    enabled = true
    filters = {
      severity = ["Low"]
      accounts = ["123456789012"]
    }
    action = {
      status_id = 3  # suppressed
      comment   = "Auto-suppressed: Low severity in dev"
    }
    skip_notification = true
  }]

  # optional: enable s3 for large rule sets
  rules_s3_bucket = {
    enabled = true
    create  = true  # set true to create bucket, false to use existing
    name    = "my-rules-bucket"
    prefix  = "rules/"
  }
```

When `create = true`, the module automatically:
- Creates an S3 bucket with versioning and encryption enabled
- Uploads rules defined in the `rules` variable to S3 as individual JSON
  files
- Configures appropriate IAM permissions for the Lambda function

You can also use an existing S3 bucket by setting `create = false` and
providing the bucket name.

### Filter Options

| Filter           | Type         | Example                                       |
|------------------|--------------|-----------------------------------------------|
| `finding_types`  | list(string) | `["Execution:Runtime/NewBinaryExecuted"]`     |
| `severity`       | list(string) | `["Critical", "High", "Medium", "Low"]`       |
| `product_name`   | list(string) | `["GuardDuty", "Inspector"]`                  |
| `resource_types` | list(string) | `["AWS::EC2::Instance"]`                      |
| `resource_tags`  | list(object) | `[{name = "Environment", value = "dev"}]`     |
| `accounts`       | list(string) | `["123456789012"]`                            |
| `regions`        | list(string) | `["us-east-1"]`                               |

### OCSF Status IDs

Based on [OCSF 1.6.0 specification](https://schema.ocsf.io/1.6.0/classes/detection_finding):

| ID  | Status        | Description                                                                      |
| --- | ------------- | -------------------------------------------------------------------------------- |
| 0   | Unknown       | The status is unknown                                                            |
| 1   | New           | The finding is new and yet to be reviewed                                        |
| 2   | In Progress   | The finding is under review                                                      |
| 3   | Suppressed    | The finding was reviewed, determined to be benign or false positive, suppressed  |
| 4   | Resolved      | The finding was reviewed, remediated and is now considered resolved              |
| 5   | Archived      | The finding was archived                                                         |
| 6   | Deleted       | The finding was deleted (e.g., created in error)                                 |
| 99  | Other         | The status is not mapped (see status attribute for source-specific value)        |

Common usage: `status_id: 5` (Archived) for accepted behavior, `status_id: 4` (Resolved) for remediated issues, `status_id: 3` (Suppressed) for false positives.

## Inputs

| Name                      | Description                                                                                                        | Type   | Default | Required |
|---------------------------|--------------------------------------------------------------------------------------------------------------------|--------|---------|----------|
| bot_version               | Version of the SecurityHub bot to use. Use 'latest' for the main branch or a specific version tag like 'v0.1.0'.   | string | "latest" | no |
| bot_repo                  | GitHub repository URL for the SecurityHub bot source code.                                                         | string | "https://github.com/cruxstack/aws-securityhubv2-bot.git" | no |
| bot_force_rebuild_id      | ID to force rebuilding the Lambda function source code. Increment this value to trigger a rebuild.                 | number | 1 | no |
| lambda_config             | Configuration for the SecurityHub bot Lambda function (memory_size, timeout, runtime, architecture, reserved_concurrent_executions). | object | {} | no |
| lambda_log_retention_days | Number of days to retain Lambda function logs in CloudWatch Logs.                                                  | number | 30 | no |
| rules                     | List of automation rules for Security Hub findings. Each rule defines filters, actions, and notification settings. | list(object) | [] | no |
| rules_s3_bucket           | S3 bucket configuration for storing automation rules. Set create=true to create a new bucket, or provide an existing bucket name. | object | {enabled = false, create = false} | no |
| slack_config              | Slack integration configuration for sending notifications (enabled, token, channel).                               | object | {} | no |
| aws_console_config        | AWS Console URL configuration for generating finding links (base_url, access_portal_url, access_role_name, securityhub_region). | object | {} | no |
| debug_enabled             | Enable debug logging in the Lambda function.                                                                       | bool | false | no |
| eventbridge_rule_config   | Configuration for the EventBridge rule that triggers the Lambda function (enabled, event_pattern).                 | object | {enabled = true, event_pattern = {...}} | no |

Additional CloudPosse context variables (`namespace`, `environment`, `stage`, `name`, `enabled`, `delimiter`, `attributes`, `tags`, etc.) are inherited from the `cloudposse/label/null` module. See [context.tf](./context.tf) for details.

## Outputs

| Name                         | Description                                                |
|------------------------------|------------------------------------------------------------|
| lambda_function_arn          | ARN of the SecurityHub v2 bot Lambda function              |
| lambda_function_name         | Name of the SecurityHub v2 bot Lambda function             |
| lambda_function_qualified_arn | Qualified ARN of the SecurityHub v2 bot Lambda function   |
| lambda_role_arn              | ARN of the IAM role used by the Lambda function            |
| lambda_role_name             | Name of the IAM role used by the Lambda function           |
| eventbridge_rule_arn         | ARN of the EventBridge rule that triggers the Lambda function |
| eventbridge_rule_name        | Name of the EventBridge rule that triggers the Lambda function |
| cloudwatch_log_group_name    | Name of the CloudWatch Log Group for Lambda function logs |
| cloudwatch_log_group_arn     | ARN of the CloudWatch Log Group for Lambda function logs  |
| rules_s3_bucket_id           | ID of the S3 bucket for rules (if created)                |
| rules_s3_bucket_arn          | ARN of the S3 bucket for rules (if created)               |

## License

This module is licensed under the MIT License. See [LICENSE](./LICENSE) for
details.

## References

- [AWS Security Hub v2 (OCSF) Documentation](https://docs.aws.amazon.com/securityhub/latest/userguide/ocsf-findings.html)
- [OCSF Schema Specification](https://schema.ocsf.io/1.6.0/classes/detection_finding)
- [Bot Source Repository](https://github.com/cruxstack/aws-securityhubv2-bot)
