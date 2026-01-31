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
}
