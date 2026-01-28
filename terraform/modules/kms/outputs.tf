output "dynamodb_key_arn" {
  description = "ARN of the DynamoDB encryption key"
  value       = aws_kms_key.dynamodb.arn
}

output "dynamodb_key_id" {
  description = "ID of the DynamoDB encryption key"
  value       = aws_kms_key.dynamodb.key_id
}

output "s3_logs_key_arn" {
  description = "ARN of the S3 logs encryption key"
  value       = aws_kms_key.s3_logs.arn
}

output "s3_logs_key_id" {
  description = "ID of the S3 logs encryption key"
  value       = aws_kms_key.s3_logs.key_id
}

output "parameter_store_key_arn" {
  description = "ARN of the Parameter Store encryption key"
  value       = aws_kms_key.parameter_store.arn
}

output "parameter_store_key_id" {
  description = "ID of the Parameter Store encryption key"
  value       = aws_kms_key.parameter_store.key_id
}
