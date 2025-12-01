# Complete Example

This example demonstrates a full-featured deployment of the SecurityHub v2 bot.

- Automation rules defined in Terraform (automatically stored in S3)
- Slack notifications enabled
- Custom AWS console configuration for federated access
- EventBridge filtering for high-severity findings only
- Extended log retention (90 days)

## Prerequisites

**Slack App**: Create a Slack app with `chat:write` scope and get:
- Bot token (starts with `xoxb-`)
- Channel ID (e.g., `C000XXXXXXX`)

## Usage

```bash
# Set required variables
export TF_VAR_rules_s3_bucket="your-rules-bucket"
export TF_VAR_slack_bot_token="xoxb-your-token"
export TF_VAR_slack_channel_id="C000XXXXXXX"

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Testing

After deployment, you can test the bot by:

1. **Trigger a test finding**: Generate a Security Hub finding or wait for one
   to be imported
2. **Check CloudWatch Logs**: View logs at `/aws/lambda/ex-prod-securityhub-bot`
3. **Verify Slack notifications**: Check your configured Slack channel
4. **Inspect Security Hub**: Confirm findings matching rules are updated

## Customization

### Add More Automation Rules

```hcl
rules = [
  {
    name    = "suppress-specific-finding"
    enabled = true
    filters = {
      finding_types = ["Software and Configuration Checks/AWS Security Best Practices"]
      resource_types = ["AwsEc2Instance"]
      resource_tags = [
        {
          name  = "Environment"
          value = "dev"
        }
      ]
    }
    action = {
      status_id = 3
      comment   = "Auto-suppressed: Dev environment"
    }
    skip_notification = true
  }
]
```

### Filter for Specific AWS Services

```hcl
eventbridge_rule_config = {
  enabled = true
  event_pattern = {
    source      = ["aws.securityhub"]
    detail-type = ["Findings Imported V2"]
    detail = {
      findings = {
        metadata = {
          product = {
            name = ["GuardDuty", "Inspector"]
          }
        }
      }
    }
  }
}
```

## Cleanup

```bash
terraform destroy
```

Note: If you created the S3 bucket with `rules_s3_bucket.create = true`, you may need to manually delete the bucket contents before destroying if Terraform cannot empty it automatically.
