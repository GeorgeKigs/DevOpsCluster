terraform {
  cloud {
    organization = "Terraform-Organization-254"

    workspaces {
      name = "EKS-trials-node-group"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      ProjectName = "eks-test"
      Owner = "George Ndungu"
    }
  }
}