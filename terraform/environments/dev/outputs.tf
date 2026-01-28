output "dynamodb_key_arn" {
  description = "ARN of the DynamoDB encryption key"
  value       = module.kms.dynamodb_key_arn
}

output "s3_logs_key_arn" {
  description = "ARN of the S3 logs encryption key"
  value       = module.kms.s3_logs_key_arn
}

output "parameter_store_key_arn" {
  description = "ARN of the Parameter Store encryption key"
  value       = module.kms.parameter_store_key_arn
}
