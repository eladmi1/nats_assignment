terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.5"
    }
  }
}
provider "aws" {
  region  = "eu-west-1"
  profile = "default"
}
