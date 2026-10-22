terraform {
  cloud {
    hostname     = "app.terraform.io"
    organization = "tecerotech"

    workspaces {
      name = "property-app-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
  }
}

provider "aws" {
  alias               = "existing"
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}
