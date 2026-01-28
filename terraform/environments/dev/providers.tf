terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "healthcare-tfstate-106237071011"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "healthcare-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "healthcare-security-platform"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
