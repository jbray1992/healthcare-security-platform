module "kms" {
  source      = "../../modules/kms"
  environment = "dev"
  project     = "healthcare-security-platform"
}
