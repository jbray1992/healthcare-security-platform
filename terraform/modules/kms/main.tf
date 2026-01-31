data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB patient records encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = {
    Name    = "${var.project}-dynamodb-key"
    Purpose = "DynamoDB patient records encryption"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project}-dynamodb-key"
  target_key_id = aws_kms_key.dynamodb.key_id
}

resource "aws_kms_key" "s3_logs" {
  description             = "KMS key for S3 CloudTrail logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 365

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project}-trail"
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        Sid    = "Allow CloudTrail log decryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:Decrypt"
        Resource = "*"
        Condition = {
          "Null" = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project}-s3-logs-key"
    Purpose = "S3 CloudTrail logs encryption"
  }
}

resource "aws_kms_alias" "s3_logs" {
  name          = "alias/${var.project}-s3-logs-key"
  target_key_id = aws_kms_key.s3_logs.key_id
}

resource "aws_kms_key" "parameter_store" {
  description             = "KMS key for Parameter Store secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = {
    Name    = "${var.project}-parameter-store-key"
    Purpose = "Parameter Store secrets encryption"
  }
}

resource "aws_kms_alias" "parameter_store" {
  name          = "alias/${var.project}-parameter-store-key"
  target_key_id = aws_kms_key.parameter_store.key_id
}
