terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Pinning: permite atualizações incrementais (minor/patch),
      # bloqueia mudanças de versão major
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}
