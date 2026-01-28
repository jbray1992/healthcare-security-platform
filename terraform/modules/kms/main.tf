# KMS Key for DynamoDB patient records encryption
resource "aws_kms_key" "dynamodb" {
  description             = "CMK for encrypting patient records in DynamoDB"
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

# KMS Key for S3 CloudTrail logs encryption
resource "aws_kms_key" "s3_logs" {
  description             = "CMK for encrypting CloudTrail logs in S3"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = {
    Name    = "${var.project}-s3-logs-key"
    Purpose = "S3 CloudTrail logs encryption"
  }
}

resource "aws_kms_alias" "s3_logs" {
  name          = "alias/${var.project}-s3-logs-key"
  target_key_id = aws_kms_key.s3_logs.key_id
}

# KMS Key for Parameter Store secrets encryption
resource "aws_kms_key" "parameter_store" {
  description             = "CMK for encrypting secrets in Parameter Store"
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
