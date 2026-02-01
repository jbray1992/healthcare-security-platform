module "kms" {
  source      = "../../modules/kms"
  environment = "dev"
  project     = "healthcare-security-platform"
}

module "dynamodb" {
  source      = "../../modules/dynamodb"
  environment = "dev"
  project     = "healthcare-security-platform"
  kms_key_arn = module.kms.dynamodb_key_arn
}

module "parameter_store" {
  source          = "../../modules/parameter-store"
  environment     = "dev"
  project         = "healthcare-security-platform"
  kms_key_arn     = module.kms.parameter_store_key_arn
  dynamodb_key_id = module.kms.dynamodb_key_id
}

module "bedrock" {
  source      = "../../modules/bedrock"
  environment = "dev"
  project     = "healthcare-security-platform"
}

module "lambda" {
  source                  = "../../modules/lambda"
  environment             = "dev"
  project                 = "healthcare-security-platform"
  dynamodb_table_name     = module.dynamodb.table_name
  dynamodb_table_arn      = module.dynamodb.table_arn
  kms_key_arn             = module.kms.dynamodb_key_arn
  parameter_store_key_arn = module.kms.parameter_store_key_arn
  kms_key_parameter_name  = module.parameter_store.dynamodb_kms_key_parameter_name
  kms_key_parameter_arn   = module.parameter_store.dynamodb_kms_key_parameter_arn
  guardrail_id            = module.bedrock.guardrail_id
  guardrail_version       = module.bedrock.guardrail_version
}

module "api_gateway" {
  source               = "../../modules/api-gateway"
  environment          = "dev"
  project              = "healthcare-security-platform"
  lambda_function_name = module.lambda.function_name
  lambda_function_arn  = module.lambda.function_arn
  lambda_invoke_arn    = module.lambda.function_invoke_arn
}

module "cloudtrail" {
  source      = "../../modules/cloudtrail"
  environment = "dev"
  project     = "healthcare-security-platform"
  kms_key_arn = module.kms.s3_logs_key_arn
}

module "athena" {
  source                 = "../../modules/athena"
  environment            = "dev"
  project                = "healthcare-security-platform"
  cloudtrail_bucket_name = module.cloudtrail.s3_bucket_name
}

module "monitoring" {
  source      = "../../modules/monitoring"
  environment = "dev"
  project     = "healthcare-security-platform"
  alert_email = ""
}
