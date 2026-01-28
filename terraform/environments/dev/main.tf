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
