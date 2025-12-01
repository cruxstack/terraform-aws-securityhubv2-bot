# =================================================================== locals ===

locals {
  enabled = module.this.enabled

  aws_account_id  = data.aws_caller_identity.current.account_id
  aws_region_name = data.aws_region.current.region
  aws_partition   = data.aws_partition.current.partition

  rules_s3_bucket_name = var.rules_s3_bucket.enabled ? (
    var.rules_s3_bucket.create ? module.rules_s3_bucket[0].bucket_id : var.rules_s3_bucket.name
  ) : ""

  lambda_environment = {
    APP_DEBUG_ENABLED              = tostring(var.debug_enabled)
    APP_AUTO_CLOSE_RULES           = length(var.rules) > 0 ? jsonencode(var.rules) : null
    APP_AUTO_CLOSE_RULES_S3_BUCKET = local.rules_s3_bucket_name
    APP_AUTO_CLOSE_RULES_S3_PREFIX = var.rules_s3_bucket.enabled ? var.rules_s3_bucket.prefix : ""
    APP_SLACK_TOKEN                = var.slack_config.enabled ? var.slack_config.token : ""
    APP_SLACK_CHANNEL              = var.slack_config.enabled ? var.slack_config.channel : ""
    APP_AWS_CONSOLE_URL            = var.aws_console_config.base_url
    APP_AWS_ACCESS_PORTAL_URL      = var.aws_console_config.access_portal_url
    APP_AWS_ACCESS_ROLE_NAME       = var.aws_console_config.access_role_name
    APP_AWS_SECURITYHUBV2_REGION   = coalesce(var.aws_console_config.securityhub_region, local.aws_region_name)
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# ===================================================================== s3 ===

module "rules_s3_bucket" {
  source  = "cloudposse/s3-bucket/aws"
  version = "4.5.0"

  count = local.enabled && var.rules_s3_bucket.enabled && var.rules_s3_bucket.create ? 1 : 0

  bucket_name             = var.rules_s3_bucket.name
  versioning_enabled      = true
  sse_algorithm           = "AES256"
  force_destroy           = false
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  context = module.this.context
}

resource "aws_s3_object" "rules" {
  for_each = local.enabled && var.rules_s3_bucket.enabled && length(var.rules) > 0 ? {
    for idx, rule in var.rules : rule.name => rule
  } : {}

  bucket       = local.rules_s3_bucket_name
  key          = "${var.rules_s3_bucket.prefix}${each.key}.json"
  content      = jsonencode([each.value])
  content_type = "application/json"
  etag         = md5(jsonencode([each.value]))

  depends_on = [module.rules_s3_bucket]
}

# ================================================================== lambda ===

module "bot_artifact" {
  source = "github.com/cruxstack/terraform-docker-artifact-packager?ref=v1.4.0"

  count = local.enabled ? 1 : 0

  attributes             = ["lambda"]
  artifact_src_path      = "/tmp/package.zip"
  artifact_dst_directory = "${path.module}/dist"
  docker_build_context   = abspath("${path.module}/assets/lambda-function")
  docker_build_target    = "package"
  force_rebuild_id       = var.bot_force_rebuild_id

  docker_build_args = {
    BOT_VERSION = var.bot_version
    BOT_REPO    = var.bot_repo
  }

  context = module.this.context
}

resource "aws_lambda_function" "this" {
  count = local.enabled ? 1 : 0

  function_name                  = module.this.id
  description                    = "Processes AWS Security Hub v2 findings with automation rules and optional Slack notifications"
  role                           = aws_iam_role.this[0].arn
  handler                        = "bootstrap"
  runtime                        = var.lambda_config.runtime
  memory_size                    = var.lambda_config.memory_size
  timeout                        = var.lambda_config.timeout
  reserved_concurrent_executions = var.lambda_config.reserved_concurrent_executions
  architectures                  = [var.lambda_config.architecture]

  filename         = module.bot_artifact[0].artifact_package_path
  source_code_hash = filebase64sha256(module.bot_artifact[0].artifact_package_path)

  environment {
    variables = local.lambda_environment
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.this
  ]

  tags = module.this.tags
}

resource "aws_cloudwatch_log_group" "lambda" {
  count = local.enabled ? 1 : 0

  name              = "/aws/lambda/${module.this.id}"
  retention_in_days = var.lambda_log_retention_days
  tags              = module.this.tags
}

# --------------------------------------------------------------- eventbridge ---

resource "aws_cloudwatch_event_rule" "securityhub" {
  count = local.enabled && var.eventbridge_rule_config.enabled ? 1 : 0

  name          = module.this.id
  description   = "Trigger SecurityHub v2 bot on findings imported"
  event_pattern = jsonencode(var.eventbridge_rule_config.event_pattern)
  tags          = module.this.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  count = local.enabled && var.eventbridge_rule_config.enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.securityhub[0].name
  target_id = "SecurityHubV2BotLambda"
  arn       = aws_lambda_function.this[0].arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = local.enabled && var.eventbridge_rule_config.enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub[0].arn
}

# ---------------------------------------------------------------------- iam ---

resource "aws_iam_role" "this" {
  count = local.enabled ? 1 : 0

  name        = module.this.id
  description = ""

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { "Service" : "lambda.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = module.this.tags
}

data "aws_iam_policy_document" "this" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:${local.aws_partition}:logs:${local.aws_region_name}:${local.aws_account_id}:log-group:/aws/lambda/${module.this.id}:*"]
  }

  statement {
    sid    = "SecurityHubAccess"
    effect = "Allow"
    actions = [
      "securityhub:BatchUpdateFindings",
      "securityhub:BatchUpdateFindingsV2"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.rules_s3_bucket.enabled ? [1] : []

    content {
      sid    = "S3RulesAccess"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        "arn:${local.aws_partition}:s3:::${local.rules_s3_bucket_name}",
        "arn:${local.aws_partition}:s3:::${local.rules_s3_bucket_name}/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "this" {
  count = local.enabled ? 1 : 0

  name   = module.this.id
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.this[0].json
}

