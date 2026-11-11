terraform {
  required_version = ">= 1.16.6"

  # Same bucket as my-custom-infra, but a DIFFERENT key so the two stacks never share state.
  backend "s3" {
    bucket       = "slyy-tata-bck-remote"
    key          = "three-tier-ecs-fargate/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}
