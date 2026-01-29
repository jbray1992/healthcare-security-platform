output "dynamodb_kms_key_parameter_name" {
  description = "Name of the parameter storing DynamoDB KMS key ID"
  value       = aws_ssm_parameter.dynamodb_kms_key_id.name
}

output "dynamodb_kms_key_parameter_arn" {
  description = "ARN of the parameter storing DynamoDB KMS key ID"
  value       = aws_ssm_parameter.dynamodb_kms_key_id.arn
}
