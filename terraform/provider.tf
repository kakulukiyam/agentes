terraform {
  required_version = ">= 1.5.0"

  # Backend Remoto S3 con Bloqueo de Estado DynamoDB (Generado en la fase de Bootstrap)
  backend "s3" {
    bucket         = "citas-escolares-tfstate-393v53"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "citas-escolares-tflocks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
