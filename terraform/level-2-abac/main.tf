terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "dcs-level-2"
      Environment = "demo"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
