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

output "patient_records_table_name" {
  description = "Name of the patient records DynamoDB table"
  value       = module.dynamodb.table_name
}

output "patient_records_table_arn" {
  description = "ARN of the patient records DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "dynamodb_kms_key_parameter_name" {
  description = "Name of the parameter storing DynamoDB KMS key ID"
  value       = module.parameter_store.dynamodb_kms_key_parameter_name
}

output "lambda_function_name" {
  description = "Name of the patient records Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the patient records Lambda function"
  value       = module.lambda.function_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the patient records Lambda function"
  value       = module.lambda.function_invoke_arn
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "cloudtrail_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = module.cloudtrail.s3_bucket_name
}

output "cloudtrail_trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = module.cloudtrail.trail_arn
}
