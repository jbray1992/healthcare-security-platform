resource "aws_ssm_parameter" "dynamodb_kms_key_id" {
  name        = "/${var.project}/${var.environment}/dynamodb-kms-key-id"
  description = "KMS Key ID for DynamoDB patient records encryption"
  type        = "SecureString"
  value       = var.dynamodb_key_id
  key_id      = var.kms_key_arn

  tags = {
    Name    = "${var.project}-dynamodb-kms-key-id"
    Purpose = "Store KMS key ID for Lambda functions"
  }
}
