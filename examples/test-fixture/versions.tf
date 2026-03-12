terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.25"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Set to true for plan-only validation tests that run without real AWS
  # credentials. Integration tests leave these at the default (false).
  skip_credentials_validation = var.aws_skip_credentials_validation
  skip_requesting_account_id  = var.aws_skip_credentials_validation
  skip_metadata_api_check     = var.aws_skip_credentials_validation

  # AWS provider v6 requires explicit credentials when skipping validation.
  access_key = var.aws_skip_credentials_validation ? "mock-access-key" : null
  secret_key = var.aws_skip_credentials_validation ? "mock-secret-key" : null
}
