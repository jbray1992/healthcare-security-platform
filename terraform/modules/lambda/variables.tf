variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for DynamoDB encryption"
  type        = string
}

variable "parameter_store_key_arn" {
  description = "ARN of the KMS key for Parameter Store"
  type        = string
}

variable "kms_key_parameter_name" {
  description = "Name of the Parameter Store parameter containing KMS key ID"
  type        = string
}

variable "kms_key_parameter_arn" {
  description = "ARN of the Parameter Store parameter"
  type        = string
}
