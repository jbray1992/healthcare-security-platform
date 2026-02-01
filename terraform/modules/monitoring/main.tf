# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project}-security-alerts"

  tags = {
    Name    = "${var.project}-security-alerts"
    Purpose = "Security alert notifications"
  }
}

# SNS Topic policy
resource "aws_sns_topic_policy" "security_alerts" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Sid    = "AllowCloudWatchPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# Email subscription (only if email provided)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge rule for KMS key deletion scheduled
resource "aws_cloudwatch_event_rule" "kms_key_deletion" {
  name        = "${var.project}-kms-key-deletion"
  description = "Alert when KMS key deletion is scheduled"

  event_pattern = jsonencode({
    source      = ["aws.kms"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["kms.amazonaws.com"]
      eventName   = ["ScheduleKeyDeletion", "DisableKey"]
    }
  })

  tags = {
    Name    = "${var.project}-kms-key-deletion"
    Purpose = "Monitor KMS key security events"
  }
}

resource "aws_cloudwatch_event_target" "kms_key_deletion" {
  rule      = aws_cloudwatch_event_rule.kms_key_deletion.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn

  input_transformer {
    input_paths = {
      eventName = "$.detail.eventName"
      keyId     = "$.detail.requestParameters.keyId"
      user      = "$.detail.userIdentity.arn"
      time      = "$.detail.eventTime"
    }
    input_template = "\"SECURITY ALERT: KMS Key Event\\n\\nEvent: <eventName>\\nKey ID: <keyId>\\nUser: <user>\\nTime: <time>\\n\\nImmediate investigation required.\""
  }
}

# EventBridge rule for IAM policy changes
resource "aws_cloudwatch_event_rule" "iam_policy_changes" {
  name        = "${var.project}-iam-policy-changes"
  description = "Alert when IAM policies are modified"

  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "CreatePolicy",
        "DeletePolicy",
        "CreatePolicyVersion",
        "DeletePolicyVersion",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "AttachUserPolicy",
        "DetachUserPolicy",
        "PutRolePolicy",
        "DeleteRolePolicy",
        "PutUserPolicy",
        "DeleteUserPolicy"
      ]
    }
  })

  tags = {
    Name    = "${var.project}-iam-policy-changes"
    Purpose = "Monitor IAM security events"
  }
}

resource "aws_cloudwatch_event_target" "iam_policy_changes" {
  rule      = aws_cloudwatch_event_rule.iam_policy_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn

  input_transformer {
    input_paths = {
      eventName = "$.detail.eventName"
      user      = "$.detail.userIdentity.arn"
      time      = "$.detail.eventTime"
    }
    input_template = "\"SECURITY ALERT: IAM Policy Change\\n\\nEvent: <eventName>\\nUser: <user>\\nTime: <time>\\n\\nReview this change for authorization.\""
  }
}

# EventBridge rule for unauthorized API calls
resource "aws_cloudwatch_event_rule" "unauthorized_api_calls" {
  name        = "${var.project}-unauthorized-api-calls"
  description = "Alert on access denied errors"

  event_pattern = jsonencode({
    source      = ["aws.cloudtrail"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      errorCode = ["AccessDenied", "UnauthorizedAccess", "AccessDeniedException"]
    }
  })

  tags = {
    Name    = "${var.project}-unauthorized-api-calls"
    Purpose = "Monitor unauthorized access attempts"
  }
}

resource "aws_cloudwatch_event_target" "unauthorized_api_calls" {
  rule      = aws_cloudwatch_event_rule.unauthorized_api_calls.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn

  input_transformer {
    input_paths = {
      eventName   = "$.detail.eventName"
      eventSource = "$.detail.eventSource"
      errorCode   = "$.detail.errorCode"
      user        = "$.detail.userIdentity.arn"
      time        = "$.detail.eventTime"
    }
    input_template = "\"SECURITY ALERT: Unauthorized API Call\\n\\nService: <eventSource>\\nAction: <eventName>\\nError: <errorCode>\\nUser: <user>\\nTime: <time>\\n\\nInvestigate potential security breach.\""
  }
}

# EventBridge rule for root account usage
resource "aws_cloudwatch_event_rule" "root_account_usage" {
  name        = "${var.project}-root-account-usage"
  description = "Alert when root account is used"

  event_pattern = jsonencode({
    source      = ["aws.signin"]
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })

  tags = {
    Name    = "${var.project}-root-account-usage"
    Purpose = "Monitor root account activity"
  }
}

resource "aws_cloudwatch_event_target" "root_account_usage" {
  rule      = aws_cloudwatch_event_rule.root_account_usage.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn

  input_transformer {
    input_paths = {
      sourceIP = "$.detail.sourceIPAddress"
      time     = "$.detail.eventTime"
    }
    input_template = "\"CRITICAL SECURITY ALERT: Root Account Sign In\\n\\nSource IP: <sourceIP>\\nTime: <time>\\n\\nRoot account usage detected. Immediate investigation required.\""
  }
}

# CloudWatch alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function error rate exceeded threshold"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    FunctionName = "${var.project}-patient-records"
  }

  tags = {
    Name    = "${var.project}-lambda-errors"
    Purpose = "Monitor Lambda function health"
  }
}

# CloudWatch alarm for API Gateway 4xx errors
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.project}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "API Gateway 4xx error rate exceeded threshold"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    ApiName = "${var.project}-api"
  }

  tags = {
    Name    = "${var.project}-api-4xx-errors"
    Purpose = "Monitor API client errors"
  }
}

# CloudWatch alarm for API Gateway 5xx errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.project}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "API Gateway 5xx error detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    ApiName = "${var.project}-api"
  }

  tags = {
    Name    = "${var.project}-api-5xx-errors"
    Purpose = "Monitor API server errors"
  }
}
